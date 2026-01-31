defmodule Mortar.Storage do
  @moduledoc """
  """

  defstruct [:adapter, :opts]

  @type t :: %__MODULE__{
          adapter: module(),
          opts: keyword()
        }

  @storage Application.compile_env(:mortar, :storage, %{
             adapter: Mortar.Storage.Local,
             opts: []
           })

  @doc """
  Retrieves the value associated with the given key.
  """
  @callback get(key :: binary()) :: {:ok, binary()} | {:error, :not_found | term()}

  @doc """
  Stores the given key-value pair.
  """
  @callback put(key :: binary(), value :: binary()) :: :ok | {:error, term()}

  @doc """
  Deletes the value associated with the given key.
  """
  @callback delete(key :: binary()) :: :ok | {:error, term()}
end
