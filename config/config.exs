import Config

# speed up bcrypt in test env
if Mix.env() == :test, do: config(:bcrypt_elixir, :log_rounds, 4)

config :esbuild,
  version: "0.14.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :logger, :console,
  format:
    if(config_env() == :dev,
      do: "[$level] $message\n",
      else: "$time $metadata[$level] $message\n"
    ),
  level: Map.fetch!(%{dev: :debug, test: :warn, prod: :info}, config_env()),
  metadata: [:request_id]

config :phoenix,
  json_library: Jason,
  plug_init_mode: if(config_env() == :prod, do: :compile, else: :runtime),
  stacktrace_depth: if(config_env() == :dev, do: 20)

config :swoosh, :api_client, false

# demo app

config :demo,
  mix_env: config_env(),
  ecto_repos: [Demo.Core.Repo]

if config_env() == :dev do
  config :demo, Demo.Interface.Endpoint,
    code_reloader: true,
    debug_errors: true
end
