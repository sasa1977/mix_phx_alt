defmodule Demo.Core.Repo do
  use Ecto.Repo,
    otp_app: :demo,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Runs the given function inside a transaction.

  This function is a wrapper around `Ecto.Repo.transaction`, with the following differences:

  - It accepts only a lambda of arity 0 or 1 (i.e. it doesn't work with multi).
  - If the lambda returns `:ok | {:ok, result}` the transaction is committed.
  - If the lambda returns `:error | {:error, reason}` the transaction is rolled back.
  - If the lambda returns any other kind of result, an exception is raised, and the transaction is rolled back.
  - The result of `transact` is the value returned by the lambda.

  This function accepts the same options as `Ecto.Repo.transaction/2`.
  """
  @spec transact((() -> result) | (module -> result), Keyword.t()) :: result
        when result: :ok | {:ok, any} | :error | {:error, any}
  def transact(fun, opts \\ []) do
    transaction_result =
      transaction(
        fn repo ->
          lambda_result =
            case Function.info(fun, :arity) do
              {:arity, 0} -> fun.()
              {:arity, 1} -> fun.(repo)
            end

          case lambda_result do
            :ok -> {__MODULE__, :transact, :ok}
            :error -> rollback({__MODULE__, :transact, :error})
            {:ok, result} -> result
            {:error, reason} -> rollback(reason)
          end
        end,
        opts
      )

    with {outcome, {__MODULE__, :transact, outcome}}
         when outcome in [:ok, :error] <- transaction_result,
         do: outcome
  end

  @impl Ecto.Repo
  def init(_context, config) do
    opts =
      config
      |> deep_merge(
        url: Demo.Config.db_url(),
        pool_size: Demo.Config.db_pool_size(),
        socket_options: if(Demo.Config.db_ipv6(), do: [:inet6], else: []),
        migration_primary_key: [type: :binary_id]
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
