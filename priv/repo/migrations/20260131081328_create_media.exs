defmodule Mortar.Repo.Migrations.CreateMedia do
  use Ecto.Migration

  def change do
    create table(:medias) do
      add :file_name, :string, null: true
      add :file_type, :string, null: false
      add :file_size, :integer, null: false
      add :source, :string, null: true
      add :md5, :string, null: false
      add :tag_strings, :string, null: false
      add :uploaded_at, :utc_datetime_usec, null: false
      timestamps()
    end

    create unique_index(:medias, [:md5])
  end
end
