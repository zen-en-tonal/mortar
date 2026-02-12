defmodule Mortar.Storage do
  @moduledoc """
  """

  @adapter Application.compile_env(:mortar, :storage_adapter, Mortar.Storage.Local)

  @doc """
  Retrieves the value associated with the given key.
  """
  @callback get(key :: binary()) :: {:ok, Enumerable.t()} | {:error, :not_found | term()}

  @doc """
  Stores the given key-value pair.
  """
  @callback put(key :: binary(), value :: Enumerable.t()) :: :ok | {:error, term()}

  @doc """
  Deletes the value associated with the given key.
  """
  @callback delete(key :: binary()) :: :ok | {:error, term()}

  @doc """
  Retrieves the value associated with the given key.
  """
  @spec get(binary()) :: {:ok, Enumerable.t()} | {:error, :not_found | term()}
  def get(key), do: @adapter.get(key)

  @doc """
  Stores the given key-value pair.
  """
  @spec put(binary(), Enumerable.t()) :: :ok | {:error, term()}
  def put(key, value), do: @adapter.put(key, value)

  @doc """
  Deletes the value associated with the given key.
  """
  @spec delete(binary()) :: :ok | {:error, term()}
  def delete(key), do: @adapter.delete(key)
end
