defmodule Mortar.Repo.Migrations.CreateEventSeq do
  use Ecto.Migration

  def up do
    execute "CREATE SEQUENCE IF NOT EXISTS event_seq"
  end

  def down do
    execute "DROP SEQUENCE IF EXISTS event_seq"
  end
end
