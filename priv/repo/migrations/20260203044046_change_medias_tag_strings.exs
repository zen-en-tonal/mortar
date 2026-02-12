defmodule Mortar.Repo.Migrations.ChangeMediasTagStrings do
  use Ecto.Migration

  def change do
    alter table(:medias) do
      modify :tag_strings, :text, null: true
    end
  end
end
