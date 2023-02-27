defmodule Demo.Interface do
  use Boundary,
    exports: [Endpoint, UrlBuilder],
    deps: [Demo.{Core, Config, Helpers}]

  @spec start_link :: Supervisor.on_start()
  def start_link do
    Supervisor.start_link(
      [
        Demo.Interface.Telemetry,
        Demo.Interface.Endpoint
      ],
      name: __MODULE__,
      strategy: :one_for_one
    )
  end

  @doc false
  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(_arg),
    do: %{id: __MODULE__, type: :supervisor, start: {__MODULE__, :start_link, []}}
end
