defmodule Demo.Core do
  use Boundary, deps: [Demo.{Config, Helpers}], exports: [User, Token, {Model, except: [Base]}]

  @spec start_link :: Supervisor.on_start()
  def start_link do
    Supervisor.start_link(
      [
        Demo.Core.Repo,
        {Phoenix.PubSub, name: Demo.PubSub},
        Demo.Core.Token
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
