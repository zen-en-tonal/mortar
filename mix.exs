defmodule Mortar.MixProject do
  use Mix.Project

  def project do
    [
      app: :mortar,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Mortar.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:roaring,
       git: "https://github.com/TernSystems/roaring_ex.git",
       ref: "5da670c8768bca34abe4d0572f4cb18ca41d068a"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:hume, "~> 0.0.11"},
      {:trie, "~> 2.0"},
      {:infer, "~> 0.2.6"},
      {:bandit, "~> 1.10"},
      {:ex_image_info, "~> 1.0"},
      {:rambo, "~> 0.3"},
      {:cachex, "~> 4.0"},
      {:ecto_cursor_based_stream, "~> 1.2"}
    ]
  end

  defp aliases do
    [
      test: ["ecto.drop", "ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
