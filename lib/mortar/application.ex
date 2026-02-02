defmodule Mortar.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @endpoint Application.compile_env!(:mortar, Mortar.Endpoint)

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Mortar.Worker.start_link(arg)
      # {Mortar.Worker, arg}
      {Mortar.Repo, []},
      {Task.Supervisor, name: Mortar.TaskSupervisor},
      {Mortar.TagSupervisor, []},
      {Bandit, @endpoint}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mortar.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
