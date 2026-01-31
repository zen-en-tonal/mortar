import Config

config :mortar, ecto_repos: [Mortar.Repo]

import_config "#{config_env()}.exs"
