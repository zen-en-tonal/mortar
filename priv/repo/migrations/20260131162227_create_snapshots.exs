defmodule Mortar.Repo.Migrations.CreateSnapshots do
  use Ecto.Migration

  def change do
    create table(:snapshots, primary_key: false) do
      add :name, :string, null: false, primary_key: true
      add :sequence, :integer, null: false
      add :data, :binary, null: false
      timestamps()
    end
  end
end
