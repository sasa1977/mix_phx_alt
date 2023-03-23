defmodule Demo.Core do
  use Boundary,
    deps: [Demo.{Config, Helpers}],
    exports: [Gettext, UrlBuilder, User, Token, {Model, except: [Base]}]

  @spec start_link(url_builder: module) :: Supervisor.on_start()
  def start_link(opts) do
    Demo.Core.UrlBuilder.configure(Keyword.fetch!(opts, :url_builder))

    Supervisor.start_link(
      [
        Demo.Core.Repo,
        oban(),
        {Phoenix.PubSub, name: Demo.PubSub},
        Demo.Core.Token
      ],
      name: __MODULE__,
      strategy: :one_for_one
    )
  end

  defp oban do
    {Oban,
     queues: [mailer: 10],
     repo: Demo.Core.Repo,
     testing: if(Demo.Helpers.mix_env() == :test, do: :manual, else: :disabled)}
  end

  @spec migrate! :: :ok
  def migrate! do
    {:ok, _, _} = Ecto.Migrator.with_repo(Demo.Core.Repo, &Ecto.Migrator.run(&1, :up, all: true))
    :ok
  end

  @doc false
  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(opts),
    do: %{id: __MODULE__, type: :supervisor, start: {__MODULE__, :start_link, [opts]}}
end
