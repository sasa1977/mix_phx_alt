defmodule Demo.Config do
  use Boundary

  use Provider,
    source: Provider.SystemEnv,
    params: [
      {:secret_key_base, dev: "6SQyoN0wWViSTd5UaarW/wZsqTX0sFgYqYfGZpehG2s6kCwJOSiVVaiLBUO5oUdB"},
      {:site_host, dev: "localhost"},
      {:db_url, dev: "ecto://postgres:postgres@localhost/demo_#{mix_env()}"},
      {:db_pool_size, type: :integer, default: 10},
      {:db_ipv6, type: :boolean, default: false}
    ]

  @spec mix_env :: :dev | :test | :prod
  def mix_env, do: Application.fetch_env!(:demo, :mix_env)
end
