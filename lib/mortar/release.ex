defmodule Mortar.Release do
  @app :mortar

  def migrate do
    load_app()

    for repo <- repos() do
      path = Ecto.Migrator.migrations_path(repo)
      run_migrations(repo, path)
    end
  end

  defp run_migrations(repo, path) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, path, :up, all: true))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
