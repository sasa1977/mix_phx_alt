defmodule Demo.Core.Repo do
  use Ecto.Repo,
    otp_app: :demo,
    adapter: Ecto.Adapters.Postgres

  @impl Ecto.Repo
  def init(_context, config) do
    opts =
      config
      |> deep_merge(pool_size: 10)
      |> deep_merge(repo_opts(Demo.Config.mix_env()))

    {:ok, opts}
  end

  defp repo_opts(:dev) do
    [
      username: "postgres",
      password: "postgres",
      hostname: "localhost",
      database: "demo_dev",
      show_sensitive_data_on_connection_error: true
    ]
  end

  defp repo_opts(:test) do
    [
      username: "postgres",
      password: "postgres",
      hostname: "localhost",
      database: "demo_test#{System.get_env("MIX_TEST_PARTITION")}",
      pool: Ecto.Adapters.SQL.Sandbox
    ]
  end

  defp repo_opts(:prod) do
    database_url =
      System.get_env("DATABASE_URL") ||
        raise """
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        """

    maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

    [
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
      socket_options: maybe_ipv6
    ]
  end

  defp deep_merge(list1, list2) do
    # Config.Reader.merge requires a top-level format of `key: kw-list`, so we're using the `:opts` key
    [opts: list1]
    |> Config.Reader.merge(opts: list2)
    |> Keyword.fetch!(:opts)
  end
end
