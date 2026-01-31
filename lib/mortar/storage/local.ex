defmodule Mortar.Storage.Local do
  @behaviour Mortar.Storage

  @impl true
  def get(_key) do
    {:error, :not_implemented}
  end

  @impl true
  def put(_key, _value) do
    {:error, :not_implemented}
  end

  @impl true
  def delete(_key) do
    {:error, :not_implemented}
  end
end
