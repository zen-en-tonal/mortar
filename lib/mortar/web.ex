defmodule Mortar.Web do
  use Plug.Builder

  if Mix.env() == :dev do
    use Plug.Debugger
  end

  use Plug.ErrorHandler

  plug(Plug.Logger)

  def endpoint do
    [
      plug: __MODULE__,
      port: Application.get_env(:mortar, Mortar.Endpoint)[:port],
      ip: Application.get_env(:mortar, Mortar.Endpoint)[:ip]
    ]
  end

  def host do
    struct!(URI, Application.get_env(:mortar, Mortar.Endpoint)[:url])
  end

  def call(conn, opts) do
    adapter = Application.get_env(:mortar, Mortar.Endpoint)[:adapter]
    adapter.call(conn, opts)
  end
end
