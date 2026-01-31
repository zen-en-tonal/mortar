defmodule Mortar.Hibernate do
  @moduledoc """
  A GenServer that hibernates processes after a specified TTL (time-to-live).
  """

  use GenServer

  require Logger

  defstruct refs: %{},
            ttls: %{}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc """
  Sets a TTL (in milliseconds) for the given process ID (pid).
  """
  def set_ttl(server, pid, ttl_ms) do
    GenServer.cast(server, {:set_ttl, pid, ttl_ms})
  end

  @impl true
  def init(_state) do
    Process.send_after(self(), :check_ttl, 1_000)
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:set_ttl, pid, ttl_ms}, state) do
    ref = Process.monitor(pid)

    state =
      state
      |> Map.update(:refs, %{}, fn refs -> Map.put(refs, ref, pid) end)
      |> Map.update(:ttls, %{}, fn ttls ->
        expiry_time = System.monotonic_time(:millisecond) + ttl_ms
        Map.put(ttls, pid, expiry_time)
      end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:check_ttl, state) do
    current_time = System.monotonic_time(:millisecond)

    {to_hibernate, remaining} =
      Enum.split_with(state.ttls, fn {_pid, expiry_time} ->
        expiry_time <= current_time
      end)

    Task.Supervisor.async_stream_nolink(
      Mortar.TaskSupervisor,
      to_hibernate,
      fn {pid, _} -> GenServer.stop(pid) end
    )
    |> Stream.run()

    Process.send_after(self(), :check_ttl, 1_000)

    {:noreply, state |> Map.put(:ttls, remaining |> Enum.into(%{}))}
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    Logger.info("Process #{inspect(pid)} has gone down. Cleaning up.")

    {pid, new_refs} = Map.pop(state.refs, ref)
    new_ttls = Map.delete(state.ttls, pid)

    new_state = %{
      refs: new_refs,
      ttls: new_ttls
    }

    {:noreply, new_state}
  end
end
