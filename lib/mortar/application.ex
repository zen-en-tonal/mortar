defmodule Mortar.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Mortar.Worker.start_link(arg)
      # {Mortar.Worker, arg}
      {Mortar.Repo, []},
      {Task.Supervisor, name: Mortar.TaskSupervisor},
      {Cachex, [Mortar.EventCache]},
      {Mortar.TagSupervisor, []},
      {Bandit, Mortar.Web.endpoint()}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mortar.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
