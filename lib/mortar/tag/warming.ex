defmodule Mortar.TagWarming do
  use GenServer

  alias Mortar.TagIndex
  alias Mortar.TagSupervisor
  alias Mortar.TaskSupervisor

  @interval :timer.seconds(10)
  @queue_majority_interval :timer.minutes(5)

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def queue_tag(tag_name) do
    GenServer.cast(__MODULE__, {:queue_tag, tag_name})
  end

  @impl true
  def init(_state) do
    schedule_warming()
    schedule_queue_majority()

    {:ok, MapSet.new()}
  end

  @impl true
  def handle_cast({:queue_tag, tag_name}, state) do
    {:noreply, MapSet.put(state, tag_name)}
  end

  @impl true
  def handle_info(:warm_tags, state) do
    Task.Supervisor.async_stream_nolink(
      TaskSupervisor,
      state,
      fn tag -> {TagSupervisor.warm_tag(tag), tag} end,
      timeout: :infinity
    )
    |> Stream.run()

    schedule_warming()

    {:noreply, MapSet.new()}
  end

  def handle_info(:queue_majority_tags, state) do
    majority_tags =
      TagIndex.filter_by_count({:>=, 0.32})
      |> Enum.map(fn {tag, _} -> tag end)

    Enum.each(majority_tags, &queue_tag/1)
    schedule_queue_majority()
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp schedule_warming, do: Process.send_after(self(), :warm_tags, @interval)

  defp schedule_queue_majority,
    do: Process.send_after(self(), :queue_majority_tags, @queue_majority_interval)
end
