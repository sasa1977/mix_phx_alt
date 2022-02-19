defmodule Demo.Config do
  use Boundary, deps: [Demo.Helpers]

  use Provider,
    source: Provider.SystemEnv,
    params: [
      {:secret_key_base, dev: "6SQyoN0wWViSTd5UaarW/wZsqTX0sFgYqYfGZpehG2s6kCwJOSiVVaiLBUO5oUdB"},
      {:public_url, dev: "http://localhost:4000"},
      {:db_url, dev: "ecto://postgres:postgres@localhost/demo_#{Demo.Helpers.mix_env()}"},
      {:db_pool_size, type: :integer, default: 10},
      {:db_ipv6, type: :boolean, default: false}
    ]
end
