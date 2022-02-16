defmodule Mix.Tasks.Demo.Gen.DefaultProdConfig do
  @shortdoc "Generates the default config for prod env."

  @moduledoc """
  #{@shortdoc}

  This task can be useful when you want to start the prod-compiled version locally using the same
  configuration as in dev:

  1. Run `mix demo.gen.default_prod_config` to generate the config settings based on the dev defaults
  2. Run `MIX_ENV=prod iex -S mix phx.server` to start the system.

  To override some of the settings, you can set the corresponding OS env variables before starting
  the system.
  """

  use Mix.Task
  use Boundary, classify_to: Demo.Mix

  @impl Mix.Task
  def run(_args) do
    :ok = Application.ensure_loaded(:demo)

    {:ok, config} = Demo.Config.fetch_all()
    path = "priv/local_prod_config.exs"
    File.write!(path, inspect(config, pretty: true, limit: :infinity))

    Mix.shell().info("""

    Generated #{path} based on #{Mix.env()} defaults.
    This file will be consulted during the app startup in prod env to set the missing OS env vars.

    To override some of the settings, you can set the corresponding OS env variables before
    starting the system.
    """)
  end
end
