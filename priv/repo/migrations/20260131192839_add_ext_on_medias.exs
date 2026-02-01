defmodule Mortar.Repo.Migrations.AddExtOnMedias do
  use Ecto.Migration

  def change do
    alter table(:medias) do
      add :ext, :string
    end
  end
end
