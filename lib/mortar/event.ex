defmodule Mortar.Event do
  import Ecto.Query

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
      |> cast(attrs, [:kind, :subject, :payload, :sequence])
      |> validate_required([:kind, :subject, :payload, :sequence])
    end
  end

  @doc """
  Publishes an event to the event stream.
  """
  @spec publish(event) :: {:ok, event} | {:error, term()} when event: t() | [t()]
  def publish(event)

  def publish(event) do
    Hume.publish(__MODULE__, stream(), event)
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
  def next_sequence() do
    [[v]] =
      Repo
      |> Ecto.Adapters.SQL.query!("SELECT nextval('event_seq')", [])
      |> Map.get(:rows)

    v
  end

  @impl true
  def events(_stream, from) do
    query =
      from e in Schema,
        where: e.sequence > ^from,
        order_by: [asc: e.sequence],
        select: e

    Repo.all(query)
    |> Enum.map(fn e ->
      {e.sequence, {String.to_atom(e.kind), e.subject, e.payload}}
    end)
    |> Hume.EventOrder.ensure_ordered()
  end

  @impl true
  def append_batch(_stream, events) do
    IO.inspect(events, label: "Appending event batch")

    entries =
      events
      |> Hume.EventOrder.to_list()
      |> Enum.map(fn {seq, {kind, subject, payload}} ->
        %Schema{}
        |> Schema.changeset(%{
          sequence: seq,
          kind: to_string(kind),
          subject: to_string(subject),
          payload: payload
        })
      end)

    case Repo.transact(fn -> {:ok, Enum.each(entries, &Repo.insert!/1)} end) do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, Error.internal("Failed to append event batch", reason: reason)}
    end
  end
end
