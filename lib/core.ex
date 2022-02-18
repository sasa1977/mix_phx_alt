defmodule Demo.Core do
  use Boundary, deps: [Demo.{Config, Helpers}], exports: [User, {Model, except: [Base]}]

  @spec start_link :: Supervisor.on_start()
  def start_link do
    Supervisor.start_link(
      [
        Demo.Core.Repo,
        {Phoenix.PubSub, name: Demo.PubSub},
        token_cleanup()
      ],
      name: __MODULE__,
      strategy: :one_for_one
    )
  end

  @doc false
  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(_arg),
    do: %{id: __MODULE__, type: :supervisor, start: {__MODULE__, :start_link, []}}

  defp token_cleanup do
    Periodic.child_spec(
      id: Demo.Core.TokenCleanup,
      name: Demo.Core.TokenCleanup,
      every: :timer.hours(1),
      on_overlap: :stop_previous,
      run: &Demo.Core.User.delete_expired_tokens/0,
      mode: if(Demo.Helpers.mix_env() == :test, do: :manual, else: :auto)
    )
  end
end
