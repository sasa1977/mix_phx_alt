import Config

config :demo, Demo.Interface.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"
config :logger, level: :info
