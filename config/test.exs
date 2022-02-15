import Config

config :demo, Demo.Core.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "demo_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :logger, level: :warn

config :phoenix, :plug_init_mode, :runtime
