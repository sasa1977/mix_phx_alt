import Config

config :demo, Demo.Core.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "demo_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :demo, Demo.Interface.Endpoint,
  code_reloader: true,
  debug_errors: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
