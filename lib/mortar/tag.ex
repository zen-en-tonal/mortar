defmodule Mortar.Tag do
  use Hume.Projection, store: Mortar.Event

  alias Mortar.TagSupervisor
  alias Mortar.TagIndex
  alias Mortar.Repo

  defstruct [:name, :bitmap_ref]

  defmodule Schema do
    use Ecto.Schema

    schema "tags" do
      field :name, :string
      field :bitmap, Ecto.RoaringBitset
      field :last_seq, :integer
      timestamps()
    end

    def changeset(schema, attrs) do
      schema
      |> Ecto.Changeset.cast(attrs, [:name, :bitmap, :last_seq])
      |> Ecto.Changeset.validate_required([:name, :bitmap, :last_seq])
      |> Ecto.Changeset.unique_constraint(:name)
    end
  end

  @doc """
  Returns the cardinality of the tag (number of unique items tagged).
  """
  def cardinality(tag), do: TagIndex.count(tag)

  @doc """
  Checks if a tag exists in the index.
  """
  def exists?(tag_name), do: TagIndex.exists?(tag_name)

  @impl true
  def init_state({__MODULE__, tag_name}) do
    {:ok, bitset} = RoaringBitset.new()

    %__MODULE__{name: tag_name, bitmap_ref: bitset}
  end

  @impl true
  def handle_event({:add_tag, subject, %{"tag" => tag_name}}, %__MODULE__{} = state)
      when state.name == tag_name do
    {media_id, ""} = Integer.parse(subject)
    RoaringBitset.insert(state.bitmap_ref, media_id)
    {:ok, state}
  end

  def handle_event({:remove_tag, subject, %{"tag" => tag_name}}, %__MODULE__{} = state)
      when state.name == tag_name do
    {media_id, ""} = Integer.parse(subject)
    RoaringBitset.remove(state.bitmap_ref, media_id)
    {:ok, state}
  end

  @impl true
  def last_snapshot({__MODULE__, tag_name}) do
    case Repo.get_by(Schema, name: tag_name) do
      nil ->
        nil

      %Schema{bitmap: bitmap, last_seq: offset} ->
        {offset, %__MODULE__{name: tag_name, bitmap_ref: bitmap}}
    end
  end

  @impl true
  def persist_snapshot({__MODULE__, tag_name}, {last_seq, state}) do
    case Repo.get_by(Schema, name: tag_name) do
      nil ->
        %Schema{}
        |> Schema.changeset(%{
          name: tag_name,
          bitmap: state.bitmap_ref,
          last_seq: last_seq
        })
        |> Repo.insert()

      %Schema{} = schema ->
        schema
        |> Schema.changeset(%{
          bitmap: state.bitmap_ref,
          last_seq: last_seq
        })
        |> Repo.update()
    end
  end
end
