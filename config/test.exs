import Config

config :mortar, Mortar.Repo,
  database: "mortar_test_db",
  username: "postgres",
  password: "password",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :mortar, Mortar.Endpoint,
  adapter: Mortar.Web.Danbooru,
  url: [host: "localhost", port: 4000, scheme: "http"],
  port: 4000,
  ip: {0, 0, 0, 0}

config :mortar, Mortar.Storage.Local, storage_path: "tmp/storage"
