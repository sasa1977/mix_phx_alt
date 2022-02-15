import Config

config :demo, Demo.Interface.Endpoint,
  code_reloader: true,
  debug_errors: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
