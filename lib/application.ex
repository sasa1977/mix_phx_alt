defmodule Demo.Application do
  use Boundary, deps: [Demo.{Core, Config, Interface}]
  use Application

  @impl Application
  def start(_type, _args) do
    Demo.Config.validate!()

    Supervisor.start_link(
      [
        {Demo.Core, url_builder: Demo.Interface.UrlBuilder},
        Demo.Interface
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  @impl Application
  def config_change(changed, _new, removed) do
    Demo.Interface.Endpoint.config_change(changed, removed)
    :ok
  end
end
