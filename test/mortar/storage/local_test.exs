defmodule Mortar.Storage.LocalTest do
  use ExUnit.Case, async: false

  alias Mortar.Storage.Local

  @test_storage_path "tmp/storage"
  @test_key "abcdef1234567890abcdef1234567890"
  @test_value "test binary data"

  defp binary_to_stream(binary) when is_binary(binary) do
    {:ok, pid} = StringIO.open(binary)
    IO.binstream(pid, :line)
  end

  defp stream_to_binary(stream) do
    stream
    |> Enum.to_list()
    |> to_string()
  end

  defp test_stream(), do: nil

  setup do
    # Clean up test storage before each test
    File.rm_rf!(@test_storage_path)
    on_exit(fn -> File.rm_rf!(@test_storage_path) end)
    :ok
  end

  describe "get/1" do
    test "returns {:error, :not_found} when key does not exist" do
      assert {:error, :not_found} = Local.get(@test_key)
    end

    test "returns {:ok, value} when key exists" do
      :ok = Local.put(@test_key, @test_value |> binary_to_stream())
      assert {:ok, stream} = Local.get(@test_key)
      assert stream_to_binary(stream) == @test_value
    end
  end

  describe "put/2" do
    test "stores key-value pair successfully" do
      assert :ok = Local.put(@test_key, binary_to_stream(@test_value))
      assert {:ok, stream} = Local.get(@test_key)
      assert stream_to_binary(stream) == @test_value
    end

    test "creates directory structure automatically" do
      key = "abcd1234567890abcdef1234567890ab"
      :ok = Local.put(key, binary_to_stream("some data"))

      expected_path = Path.join([@test_storage_path, "ab", "cd", "1234567890abcdef1234567890ab"])
      assert File.exists?(expected_path)
    end

    test "is idempotent - can put same value multiple times" do
      assert :ok = Local.put(@test_key, @test_value |> binary_to_stream())
      assert :ok = Local.put(@test_key, @test_value |> binary_to_stream())
      assert {:ok, stream} = Local.get(@test_key)
      assert stream_to_binary(stream) == @test_value
    end

    test "overwrites existing value" do
      :ok = Local.put(@test_key, binary_to_stream("old value"))
      :ok = Local.put(@test_key, binary_to_stream("new value"))
      assert {:ok, stream} = Local.get(@test_key)
      assert stream_to_binary(stream) == "new value"
    end
  end

  describe "delete/1" do
    test "deletes existing key successfully" do
      :ok = Local.put(@test_key, binary_to_stream(@test_value))
      assert :ok = Local.delete(@test_key)
      assert {:error, :not_found} = Local.get(@test_key)
    end

    test "is idempotent - returns :ok when key does not exist" do
      assert :ok = Local.delete(@test_key)
      assert :ok = Local.delete(@test_key)
    end

    test "only deletes the specific key" do
      key1 = "aabbccddaabbccddaabbccddaabbccdd"
      key2 = "aabbccdd11223344aabbccdd11223344"

      :ok = Local.put(key1, binary_to_stream("value1"))
      :ok = Local.put(key2, binary_to_stream("value2"))

      assert :ok = Local.delete(key1)
      assert {:error, :not_found} = Local.get(key1)
      assert {:ok, _} = Local.get(key2)
    end
  end

  describe "directory structure" do
    test "uses first 2 chars and second 2 chars for directory hierarchy" do
      key = "12345678901234567890123456789012"
      :ok = Local.put(key, binary_to_stream("some data"))

      expected_path = Path.join([@test_storage_path, "12", "34", "5678901234567890123456789012"])
      assert File.exists?(expected_path)
    end

    test "handles different key prefixes correctly" do
      keys = [
        "aabbccdd0000000000000000000000aa",
        "aabbccdd1111111111111111111111bb",
        "bbccddee0000000000000000000000cc"
      ]

      for key <- keys do
        :ok = Local.put(key, binary_to_stream("value_#{key}"))
      end

      # Verify all files exist
      for key <- keys do
        assert {:ok, _} = Local.get(key)
      end

      # Verify directory structure
      assert File.exists?(Path.join([@test_storage_path, "aa", "bb"]))
      assert File.exists?(Path.join([@test_storage_path, "bb", "cc"]))
    end
  end

  describe "concurrent operations" do
    test "handles multiple put operations" do
      keys =
        for i <- 1..10 do
          <<i::128>> |> Base.encode16(case: :lower)
        end

      tasks =
        for key <- keys do
          Task.async(fn -> Local.put(key, binary_to_stream("value_#{key}")) end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, &(&1 == :ok))

      for key <- keys do
        expected = "value_#{key}"
        assert {:ok, stream} = Local.get(key)
        assert stream_to_binary(stream) == expected
      end
    end
  end
end
