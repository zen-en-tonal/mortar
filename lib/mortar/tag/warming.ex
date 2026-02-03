defmodule Mortar.TagWarming do
  use GenServer

  alias Mortar.Tag
  alias Mortar.TagIndex
  alias Mortar.TaskSupervisor

  @interval :timer.seconds(10)
  @queue_minority_interval :timer.minutes(5)

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def queue_tag(tag_name) do
    GenServer.cast(__MODULE__, {:queue_tag, tag_name})
  end

  @impl true
  def init(_state) do
    schedule_warming()
    # schedule_queue_minotiry()

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
      &Tag.warm/1,
      timeout: :infinity
    )
    |> Stream.run()

    schedule_warming()

    {:noreply, MapSet.new()}
  end

  def handle_info(:queue_minority_tags, state) do
    minority_tags =
      TagIndex.minority_reported_tags()
      |> Enum.map(fn {tag, _} -> tag end)

    Enum.each(minority_tags, &queue_tag/1)

    schedule_queue_minotiry()

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp schedule_warming, do: Process.send_after(self(), :warm_tags, @interval)

  defp schedule_queue_minotiry,
    do: Process.send_after(self(), :queue_minority_tags, @queue_minority_interval)
end
