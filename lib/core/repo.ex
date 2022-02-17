defmodule Demo.Core.Repo do
  use Ecto.Repo,
    otp_app: :demo,
    adapter: Ecto.Adapters.Postgres

  @impl Ecto.Repo
  def init(_context, config) do
    opts =
      config
      |> deep_merge(
        url: Demo.Config.db_url(),
        pool_size: Demo.Config.db_pool_size(),
        socket_options: if(Demo.Config.db_ipv6(), do: [:inet6], else: [])
      )
      |> deep_merge(repo_opts(Demo.Helpers.mix_env()))

    {:ok, opts}
  end

  defp repo_opts(:dev), do: [show_sensitive_data_on_connection_error: true]
  defp repo_opts(:test), do: [pool: Ecto.Adapters.SQL.Sandbox]
  defp repo_opts(:prod), do: []

  defp deep_merge(list1, list2) do
    # Config.Reader.merge requires a top-level format of `key: kw-list`, so we're using the `:opts` key
    [opts: list1]
    |> Config.Reader.merge(opts: list2)
    |> Keyword.fetch!(:opts)
  end
end
