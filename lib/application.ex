defmodule Demo.Application do
  use Boundary, deps: [Demo.Core, Demo.Interface]
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      Demo.Core.Repo,
      Demo.Interface.Telemetry,
      {Phoenix.PubSub, name: Demo.PubSub},
      Demo.Interface.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Demo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def config_change(changed, _new, removed) do
    Demo.Interface.Endpoint.config_change(changed, removed)
    :ok
  end
end
