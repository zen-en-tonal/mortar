import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :mortar, Mortar.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :mortar, Mortar.Storage.Local, storage_path: System.get_env("STORAGE_PATH") || "/data"

  host = System.get_env("HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :mortar, Mortar.Endpoint,
    adapter: Mortar.Web.Danbooru,
    url: [host: host, port: 443, scheme: "https"],
    port: port,
    ip: {0, 0, 0, 0}

  image_proxy_url = System.get_env("IMAGE_PROXY_URL") || "https://#{host}"
  config :mortar, Mortar.Web.Danbooru, image_proxy_url: image_proxy_url |> URI.parse()
end
