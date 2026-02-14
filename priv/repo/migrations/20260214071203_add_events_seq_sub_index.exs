defmodule Mortar.Repo.Migrations.AddEventsSeqSubIndex do
  use Ecto.Migration

  def change do
    create index(:events, [:sequence, :subject])
  end
end
