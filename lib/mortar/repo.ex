defmodule Mortar.Repo do
  use Ecto.Repo,
    otp_app: :mortar,
    adapter: Ecto.Adapters.Postgres
end
