defmodule Demo.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Demo.Repo,
      DemoWeb.Telemetry,
      {Phoenix.PubSub, name: Demo.PubSub},
      DemoWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Demo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
