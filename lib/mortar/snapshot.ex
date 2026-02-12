defmodule Mortar.Snapshot do
  alias Mortar.Repo

  defmodule Schema do
    use Ecto.Schema

    @primary_key {:name, :string, autogenerate: false}

    schema "snapshots" do
      field :sequence, :integer
      field :data, :binary
      timestamps()
    end

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [:name, :sequence, :data])
      |> Ecto.Changeset.validate_required([:name, :sequence, :data])
      |> Ecto.Changeset.unique_constraint(:name)
    end
  end

  @doc """
  Retrieves a snapshot by name.
  """
  def get(name) do
    case Repo.get(Schema, name) do
      nil ->
        nil

      snapshot ->
        {snapshot.sequence, :erlang.binary_to_term(snapshot.data)}
    end
  end

  @doc """
  Stores a snapshot with the given name, sequence, and data.
  """
  def put(name, {sequence, data}) do
    changes = %{sequence: sequence, data: :erlang.term_to_binary(data)}

    res =
      case Repo.get(Schema, name) do
        nil -> %Schema{name: name}
        snapshot -> snapshot
      end
      |> Schema.changeset(changes)
      |> Repo.insert_or_update()

    case res do
      {:ok, _snapshot} ->
        :ok

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
