defmodule Mortar.FFProbe do
  @ffprobe Application.compile_env(:mortar, :ffprobe_path, "ffprobe")
  @args [
    "-v",
    "quiet",
    "-show_format",
    "-show_streams",
    "-print_format",
    "json",
    "pipe:"
  ]

  def extract(binary) do
    case Rambo.run(ffprobe(), @args, in: binary) do
      {:ok, %{status: 0, out: out}} ->
        {:ok, Jason.decode!(out)}

      {:ok, %{status: status, err: err}} ->
        {:error, "ffprobe exited with status #{status}: #{err}"}

      {:error, reason} ->
        {:error, "ffprobe failed: #{inspect(reason)}"}
    end
  end

  defp ffprobe, do: System.find_executable(@ffprobe)
end
