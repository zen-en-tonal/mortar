defmodule Mortar.Event do
  require Ecto.Query
  alias Mortar.Error
  alias Mortar.Repo

  @behaviour Hume.EventStore

  @stream "mortar_events"

  @type t :: {kind :: atom(), subject :: term(), payload :: map()}
  @type invalid_event :: {:invalid, reason :: binary()}

  defmodule Schema do
    @moduledoc false

    use Ecto.Schema
    import Ecto.Changeset

    schema "events" do
      field :sequence, :integer
      field :kind, :string
      field :subject, :string
      field :payload, :map
      timestamps()
    end

    def changeset(struct, attrs) do
      struct
      |> cast(attrs, [:kind, :subject, :payload])
      |> validate_required([:kind, :subject, :payload])
    end
  end

  @doc """
  Publishes an event to the event stream.
  """
  def publish(event, stream \\ stream())

  def publish(event, stream) do
    Hume.publish(__MODULE__, stream, event)
    |> case do
      {:ok, _} ->
        {:ok, event}

      {:error, reason} ->
        {:error, Error.internal("Failed to publish event", reason: reason)}
    end
  end

  @doc """
  Returns the name of the event stream.
  """
  def stream(), do: @stream

  @doc """
  Composes an event with the given kind, subject, and optional payload.
  """
  def compose(kind, subject, payload \\ %{}) do
    {kind, subject, payload}
  end

  @impl true
  def events(stream, from) do
    query =
      case stream do
        @stream -> Schema
        _ -> Ecto.Query.from(Schema, where: [subject: ^stream])
      end

    Repo.cursor_based_stream(query,
      cursor_field: :sequence,
      after_cursor: from,
      order: :asc,
      parallel: false
    )
    |> Stream.map(fn e ->
      {e.sequence, {String.to_atom(e.kind), e.subject, e.payload}}
    end)
  end

  @impl true
  def append_batch(_stream, events) do
    entries =
      events
      |> Enum.map(fn {kind, subject, payload} ->
        %Schema{}
        |> Schema.changeset(%{
          kind: to_string(kind),
          subject: to_string(subject),
          payload: payload
        })
      end)

    result =
      Repo.transact(fn ->
        Enum.reduce_while(entries, :ok, fn entry, _acc ->
          case Repo.insert(entry) do
            {:ok, record} -> {:cont, {:ok, record}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
      end)

    case result do
      {:ok, %Schema{} = record} -> {:ok, record.sequence}
      {:error, reason} -> {:error, Error.internal("Failed to append event batch", reason: reason)}
    end
  end
end
