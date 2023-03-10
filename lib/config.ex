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

  defoverridable validate!: 0

  # spec is already included via `use Provider`
  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def validate! do
    configure_local_prod()
    super()
  end

  defp configure_local_prod do
    # In prod mix env we'll prime the unset OS env vars from the local config script. This is used
    # to simplify running the prod-compiled version on a local dev machine.
    # See `Mix.Tasks.Demo.Gen.DefaultProdConfig` for details.
    for true <- [Demo.Helpers.mix_env() == :prod],
        config_file = "#{Application.app_dir(:demo, "priv")}/local_prod_config.exs",
        {:ok, config} <- [File.read(config_file)],
        {config, _bindings} = Code.eval_string(config),
        {key, value} <- config,
        key = String.upcase(to_string(key)),
        is_nil(System.get_env(key)),
        do: System.put_env(key, to_string(value))
  end
end
