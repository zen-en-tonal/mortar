import Config

config :mortar, Mortar.Repo,
  database: "mortar_test_db",
  username: "postgres",
  password: "password",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
