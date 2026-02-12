defmodule Mortar.LRU do
  use GenServer

  defstruct refs: %{}, pids: :queue.new(), size: 128

  def start_link(opts \\ []) do
    {size, opts} = Keyword.pop(opts, :size, 128)

    GenServer.start_link(__MODULE__, size, opts)
  end

  def touch(lru, pid) do
    GenServer.cast(lru, {:touch, pid})
  end

  @impl true
  def init(size) do
    {:ok, %__MODULE__{size: size}}
  end

  @impl true
  def handle_cast({:touch, pid}, %__MODULE__{} = state) do
    ref = Process.monitor(pid)

    {to_kill, new_queue} =
      touch_in_queue(state.pids, pid)
      |> out_queue_until(state.size)

    for pid <- to_kill, do: Process.exit(pid, :normal)

    {:noreply,
     %__MODULE__{
       state
       | refs: put_in(state.refs, [ref], pid),
         pids: new_queue
     }}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %__MODULE__{} = state) do
    case pop_in(state.refs, [ref]) do
      {nil, _refs} ->
        {:noreply, state}

      {pid, new_refs} ->
        new_queue = :queue.filter(fn x -> x != pid end, state.pids)

        {:noreply,
         %__MODULE__{
           state
           | refs: new_refs,
             pids: new_queue
         }}
    end
  end

  defp touch_in_queue(queue, pid) do
    queue = :queue.filter(fn x -> x != pid end, queue)
    :queue.in(pid, queue)
  end

  defp out_queue_until(queue, size) do
    case Enum.max([0, :queue.len(queue) - size]) do
      0 ->
        {[], queue}

      size ->
        Enum.reduce_while(1..size, {[], queue}, fn _, {acc, queue} ->
          case :queue.out(queue) do
            {{:value, item}, new_queue} -> {:cont, {[item | acc], new_queue}}
            {:empty, new_queue} -> {:halt, {acc, new_queue}}
          end
        end)
    end
  end
end
