defmodule Mortar.Repo.Migrations.CreateTag do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string, null: false
      add :bitmap, :binary, null: false
      timestamps()
    end

    create unique_index(:tags, [:name])
  end
end
