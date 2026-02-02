defmodule Mortar.Web do
  use Plug.Builder

  if Mix.env() == :dev do
    use Plug.Debugger
  end

  use Plug.ErrorHandler

  plug(Plug.Logger)
  plug(Application.compile_env(:mortar, Mortar.Web)[:adapter])

  def host do
    struct!(URI, Application.get_env(:mortar, Mortar.Web)[:url])
  end
end
