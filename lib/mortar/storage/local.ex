defmodule Mortar.Storage.Local do
  @moduledoc """
  A local storage adapter for Mortar that implements the Mortar.Storage behaviour.

  This adapter has configurable options that can be set in the application configuration.
  The available configuration options are:
    * `:storage_path` - The file system path where data will be stored. Default is `"./data"`.

  ## Configuration Example
      config :mortar, Mortar.Storage.Local,
        storage_path: "/path/to/storage"

  The `key` must be a md5 hash string to ensure valid file naming.
  And the `value` is stored as a binary file at the specified storage path.

  A directory under `:storage_path` is created automatically if it does not exist.
  The directory structure is a tree based on the first 2 characters and secound 2 ones of the md5 hash key.

  An opperation with effects is idempotence and will not fail if the target state is already achieved.
  For example, putting a key-value pair that already exists with the same value will succeed without error.
  """

  @behaviour Mortar.Storage

  @impl true
  def get(key) do
    path = build_file_path(key)

    case File.exists?(path) do
      true -> {:ok, File.stream!(path, 1024)}
      false -> {:error, :not_found}
    end
  end

  @impl true
  def put(key, stream) do
    path = build_file_path(key)
    dir = Path.dirname(path)

    :ok = File.mkdir_p(dir)

    :ok =
      Stream.into(stream, File.stream!(path))
      |> Stream.run()

    :ok
  end

  @impl true
  def delete(key) do
    path = build_file_path(key)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_file_path(key) do
    <<first::binary-size(2), second::binary-size(2), rest::binary>> = key
    Path.join([storage_path(), first, second, rest])
  end

  def storage_path do
    Application.get_env(:mortar, Mortar.Storage.Local)[:storage_path] || "./data"
  end
end
