defmodule Mortar.MediaTest do
  use ExUnit.Case

  alias Mortar.Query
  alias Mortar.Media
  alias Mortar.Tag

  @test_png Path.expand("../support/fixtures/20260216_random.png", __DIR__)

  setup_all do
    tags = ~w(test foo bar)
    stream = File.stream!(@test_png, 2048)
    {:ok, media} = Media.upload(stream, tags: tags)

    for tag <- tags, do: Tag.warm_sync(tag)
    Tag.warm_sync("__all__")

    {:ok, %{media: media}}
  end

  describe "query/2" do
    test "returns media matching query", %{media: expect} do
      {:ok, results} = Media.query(Query.cond_and("test", "foo"))
      assert Enum.any?(results, fn m -> m.id == expect.id end)
    end

    test "returns empty list for non-matching query" do
      {:ok, results} = Media.query(Query.cond_and("nonexistent", "tag"))
      assert results == []
    end

    test "returns all media for __all__ query", %{media: expect} do
      {:ok, results} = Media.query("__all__")
      assert Enum.any?(results, fn m -> m.id == expect.id end)
    end

    test "returns media matching OR condition", %{media: expect} do
      {:ok, results} = Media.query(Query.cond_or("test", "nonexistent"))
      assert Enum.any?(results, fn m -> m.id == expect.id end)
    end

    test "returns media not matching NOT condition", %{media: expect} do
      {:ok, results} = Media.query(Query.cond_not("test"))
      refute Enum.any?(results, fn m -> m.id == expect.id end)
    end

    test "returns all media with empty query", %{media: expect} do
      {:ok, results} = Media.query(nil)
      {:ok, ^results} = Media.query("")
      assert Enum.any?(results, fn m -> m.id == expect.id end)
    end
  end
end
