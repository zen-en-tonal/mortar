defmodule Mortar.Repo.Migrations.CreateEvent do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :sequence, :integer, null: false
      add :kind, :string, null: false
      add :subject, :string, null: false
      add :payload, :map, null: false
      timestamps()
    end

    create index(:events, asc: :sequence)
  end
end
