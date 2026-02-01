defmodule Mortar.Repo.Migrations.AddMetadataOnMedias do
  use Ecto.Migration

  def change do
    alter table(:medias) do
      add :metadata, :map, default: %{}
    end
  end
end
