defmodule Mortar.TagSupervisor do
  use Supervisor

  alias Mortar.Tag
  alias Mortar.TagIndex
  alias Mortar.TagRegistry
  alias Mortar.TagDynamicSupervisor
  alias Mortar.TagWarming
  alias Mortar.Event
  alias Mortar.Error
  alias Mortar.TagLRU

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def via_tuple(tag_name) do
    {:via, Registry, {TagRegistry, {Tag, tag_name}}}
  end

  @doc """
  Starts a projector for the given tag name.
  """
  def start_tag(tag_name) do
    projection = {Tag, tag_name}
    supervisor = {:via, PartitionSupervisor, {TagDynamicSupervisor, projection}}

    stream =
      case tag_name do
        "__all__" -> Event.stream()
        _ -> tag_name
      end

    spec = %{
      id: projection,
      start:
        {Hume.Projection, :start_link,
         [
           Tag,
           [
             stream: stream,
             projection: projection,
             name: via_tuple(tag_name)
           ]
         ]},
      restart: :temporary,
      type: :worker
    }

    case DynamicSupervisor.start_child(supervisor, spec) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid

      {:error, reason} ->
        IO.inspect(reason, label: "Error starting tag projector")
        raise Error.internal("Failed to start projector", reason: reason)
    end
  end

  @doc """
  Ensures that a tag projector is started for the given tag name.

  Returns the PID of the started or existing projector.
  """
  def ensure_tag_started(tag_name) do
    {:via, Registry, {reg, key}} = via_tuple(tag_name)

    pid =
      case Registry.lookup(reg, key) do
        [{pid, _value}] ->
          pid

        [] ->
          start_tag(tag_name)
      end

    Mortar.LRU.touch(TagLRU, pid)

    pid
  end

  @doc """
  Returns the state of the tag projector for the given tag name,
  or `nil` if the tag does not exist.
  """
  def get_state(tag, opts \\ [])

  def get_state(non_tag, _) when non_tag in ["", nil] do
    nil
  end

  def get_state(tag_name, opts) do
    if TagIndex.exists?(tag_name) do
      pid = ensure_tag_started(tag_name)
      Hume.state(pid, opts)
    else
      nil
    end
  end

  @doc """
  Takes a snapshot of the tag projector for the given tag name.
  """
  def take_snapshot(tag_name) do
    pid = ensure_tag_started(tag_name)
    Hume.Projection.take_snapshot(pid)
  end

  def warm_tag(tag_name) do
    if TagIndex.exists?(tag_name) do
      pid = ensure_tag_started(tag_name)
      Hume.Projection.catch_up_sync(pid, :infinity)
    end

    :ok
  end

  @impl true
  def init(:ok) do
    children = [
      {Registry, keys: :unique, name: TagRegistry},
      {PartitionSupervisor,
       child_spec: DynamicSupervisor, name: TagDynamicSupervisor, partitions: 4},
      {Mortar.LRU, name: TagLRU, size: 128},
      {TagIndex, name: TagIndex, stream: Event.stream(), projection: TagIndex},
      {TagWarming, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
