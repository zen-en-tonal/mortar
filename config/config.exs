import Config

config :mortar, ecto_repos: [Mortar.Repo]

config :mortar, storage_adapter: Mortar.Storage.Local

config :mortar, Mortar.Endpoint,
  plug: Mortar.Web,
  port: 4000,
  ip: {0, 0, 0, 0}

config :mortar, Mortar.Web,
  adapter: Mortar.Web.Danbooru,
  url: [host: "192.168.1.105", port: 4000, scheme: "http"]

import_config "#{config_env()}.exs"
