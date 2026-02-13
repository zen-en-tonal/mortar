defmodule Mortar.FFProbe do
  use GenServer

  @ffprobe Application.compile_env(:mortar, :ffprobe_path, "ffprobe")
  @args [
    "-v",
    "quiet",
    "-show_format",
    "-show_streams",
    "-print_format",
    "json"
  ]

  def start_link(opts \\ []) do
    ffprobe() || raise "ffprobe executable not found in PATH"
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @spec extract(File.Stream.t()) :: {:ok, map()} | {:error, String.t()}
  def extract(stream) do
    :poolboy.transaction(
      __MODULE__,
      fn pid -> GenServer.call(pid, {:extract, stream}, 30_000) end
    )
  end

  def poolboy_config do
    [
      name: {:local, __MODULE__},
      worker_module: __MODULE__,
      size: 8,
      max_overflow: 2
    ]
  end

  defp args(file_path), do: @args ++ [file_path]

  defp ffprobe, do: System.find_executable(@ffprobe)

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:extract, stream}, _from, state) do
    result =
      case Rambo.run(ffprobe(), args(stream.path)) do
        {:ok, %{status: 0, out: out}} ->
          {:ok, Jason.decode!(out)}

        {:ok, %{status: status, err: err}} ->
          {:error, "ffprobe exited with status #{status}: #{err}"}

        {:error, reason} ->
          {:error, "ffprobe failed: #{inspect(reason)}"}
      end

    {:reply, result, state}
  end
end
