defmodule Demo.Core do
  use Boundary,
    deps: [Demo.{Config, Helpers}],
    exports: [PublicUrl, User, Token, {Model, except: [Base]}]

  @spec start_link(public_url: module) :: Supervisor.on_start()
  def start_link(opts) do
    Demo.Core.PublicUrl.configure(Keyword.fetch!(opts, :public_url))

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
  def child_spec(opts),
    do: %{id: __MODULE__, type: :supervisor, start: {__MODULE__, :start_link, [opts]}}
end
