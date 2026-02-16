defmodule Mortar.Tag do
  use Hume.Projection, store: Mortar.Event

  alias Mortar.TagWarming
  alias Mortar.TagSupervisor
  alias Mortar.TagIndex
  alias Mortar.Repo
  alias Mortar.Event

  defstruct [:name, :bitmap_ref]

  @type t :: %__MODULE__{
          name: binary(),
          bitmap_ref: reference()
        }

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

  @doc """
  Returns a list of suggested tags based on the given prefix.
  Each suggestion is a tuple of `{tag_name, count}`.
  """
  def suggest(prefix), do: TagIndex.suggest(prefix)

  @doc """
  Returns the Tag state for the given tag name.
  If the tag does not exist, returns a new Tag with an empty bitmap.
  """
  def fetch(tag_name) do
    case TagSupervisor.get_state(tag_name, [:dirty, timeout: 1_000]) do
      nil ->
        {:ok, empty_bitmap} = RoaringBitset.new()
        %__MODULE__{name: tag_name, bitmap_ref: empty_bitmap}

      %__MODULE__{} = state ->
        state
    end
  end

  @doc """
  Queues the tag for warming.
  """
  def queue_warm(tag_name) when is_binary(tag_name) do
    TagWarming.queue_tag(tag_name)
  end

  def queue_warm(tags) when is_list(tags) do
    Enum.each(tags, &TagWarming.queue_tag/1)
  end

  def warm_all_tag() do
    TagWarming.queue_tag("__all__")
  end

  @doc """
  Warms the tag synchronously by ensuring it is started and catching up to the latest events.
  """
  def warm_sync(tag_name) do
    TagSupervisor.warm_tag(tag_name)
  end

  @spec add(binary(), integer() | binary()) :: :ok
  def add(tag_name, media_id) do
    Event.compose(:add_tag, tag_name, %{"media_id" => media_id})
    |> Event.publish(tag_name)
  end

  @spec remove(binary(), integer() | binary()) :: :ok
  def remove(tag_name, media_id) do
    Event.compose(:remove_tag, tag_name, %{"media_id" => media_id})
    |> Event.publish(tag_name)
  end

  @impl true
  def init_state({__MODULE__, tag_name}) do
    {:ok, bitset} = RoaringBitset.new()

    %__MODULE__{name: tag_name, bitmap_ref: bitset}
  end

  @impl true
  def handle_event({:add_tag, tag_name, %{"media_id" => subject}}, %__MODULE__{} = state)
      when state.name == tag_name do
    media_id =
      case subject do
        id when is_integer(id) ->
          id

        id when is_binary(id) ->
          String.to_integer(id)
      end

    RoaringBitset.insert(state.bitmap_ref, media_id)
    {:ok, state}
  end

  def handle_event({:remove_tag, tag_name, %{"media_id" => subject}}, %__MODULE__{} = state)
      when state.name == tag_name do
    media_id =
      case subject do
        id when is_integer(id) ->
          id

        id when is_binary(id) ->
          String.to_integer(id)
      end

    RoaringBitset.remove(state.bitmap_ref, media_id)
    {:ok, state}
  end

  def handle_event({:upload_media, subject, _}, %__MODULE__{} = state)
      when state.name == "__all__" do
    {media_id, ""} = Integer.parse(subject)
    RoaringBitset.insert(state.bitmap_ref, media_id)
    {:ok, state}
  end

  def handle_event(_event, %__MODULE__{} = state) do
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
    res =
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

    case res do
      {:ok, _schema} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
