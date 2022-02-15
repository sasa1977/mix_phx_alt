import Config

config :demo, Demo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "demo_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :demo, Demo.Interface.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "K0Qh5bXJnroiweVp9bE07TKC1BeaLYxmJ61HRU9D6u6K0+UqCfCUSyyF9UMyODvz",
  server: false

config :logger, level: :warn

config :phoenix, :plug_init_mode, :runtime
