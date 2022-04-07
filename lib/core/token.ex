defmodule Demo.Core.Token do
  import Demo.Helpers
  import Ecto.Query

  alias Demo.Core.Model.{Token, User}
  alias Demo.Core.Repo

  @type value :: String.t()

  @doc """
  Creates the new token and retuns its value.

  Notes:

    - we only store the hash of the token value to the database (to prevent unauthorized usage of the tokens)
    - the returned value is url64 encoded
  """
  @spec create(User.t(), Token.type(), map) :: value
  def create(user, type, payload \\ %{}) do
    token_bytes = :crypto.strong_rand_bytes(32)
    token = Base.url_encode64(token_bytes, padding: false)

    # we're only storing the token hash, to prevent the people with the database access from the
    # unauthorized usage of the token
    Repo.insert!(%Token{
      user_id: user && user.id,
      type: type,
      hash: ok!(hash(token)),
      payload: payload
    })

    token
  end

  @spec valid?(value, Token.type()) :: boolean
  def valid?(token, type) do
    case hash(token) do
      {:ok, hash} -> Repo.exists?(valid_tokens_query(), hash: hash, type: type)
      :error -> false
    end
  end

  @spec fetch(value, Token.type()) :: {:ok, Token.t()} | :error
  def fetch(token, type) do
    with {:ok, hash} <- hash(token),
         token =
           Repo.one(
             from token in valid_token_query(hash, type),
               left_join: user in assoc(token, :user),
               preload: [user: user]
           ),
         :ok <- validate(token != nil),
         do: {:ok, token}
  end

  @spec spend(value, Token.type()) :: {:ok, Token.t()} | {:error, :invalid_token}
  def spend(token, type) do
    # Using delete_all with select ensures we won't spend the same token twice.
    with {:ok, hash} <- hash(token),
         {count, tokens} = Repo.delete_all(select(valid_token_query(hash, type), [token], token)),
         :ok <- validate(count == 1),
         do: {:ok, Repo.preload(hd(tokens), :user)},
         else: (_ -> {:error, :invalid_token})
  end

  @spec delete(value, Token.type()) :: :ok
  def delete(token, type) do
    with {:ok, hash} <- hash(token), do: Repo.delete_all(where(Token, hash: ^hash, type: ^type))
    :ok
  end

  @spec delete_all(User.t()) :: :ok
  def delete_all(user) do
    Repo.delete_all(where(Token, user_id: ^user.id))
    :ok
  end

  defp hash(token) do
    with {:ok, token_bytes} <- Base.url_decode64(token, padding: false),
         do: {:ok, :crypto.hash(:sha256, token_bytes)}
  end

  defmacrop token_valid?(token) do
    Token.validities()
    |> Enum.map(fn {type, validity} ->
      quote do
        unquote(token).type == unquote(type) and
          unquote(token).inserted_at > ago(unquote(validity), "day")
      end
    end)
    |> Enum.reduce(&quote(do: unquote(&2) or unquote(&1)))
  end

  defp valid_tokens_query, do: from(token in Token, where: token_valid?(token))
  defp invalid_tokens_query, do: from(token in Token, where: not token_valid?(token))

  defp valid_token_query(hash, type),
    do: where(valid_tokens_query(), hash: ^hash, type: ^type)

  @doc false
  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(_arg), do: token_cleanup()

  defp token_cleanup do
    Periodic.child_spec(
      id: __MODULE__.Cleanup,
      name: __MODULE__.Cleanup,
      every: :timer.hours(1),
      on_overlap: :stop_previous,
      run: fn -> Repo.delete_all(invalid_tokens_query()) end,
      mode: if(Demo.Helpers.mix_env() == :test, do: :manual, else: :auto)
    )
  end
end
