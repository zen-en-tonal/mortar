defmodule Mortar.Repo.Migrations.ChangeEventSequence do
  use Ecto.Migration

  def up do
    alter table(:events) do
      modify(:sequence, :integer, default: fragment("nextval('event_seq')"))
    end
  end

  def down do
    alter table(:events) do
      modify(:sequence, :integer)
    end
  end
end
