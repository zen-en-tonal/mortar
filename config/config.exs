import Config

config :mortar, ecto_repos: [Mortar.Repo]

config :mortar, storage_adapter: Mortar.Storage.Local

import_config "#{config_env()}.exs"
