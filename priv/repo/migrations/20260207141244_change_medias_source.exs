defmodule Mortar.Repo.Migrations.ChangeMediasSource do
  use Ecto.Migration

  def change do
    alter table(:medias) do
      modify :source, :text, null: true
    end
  end
end
