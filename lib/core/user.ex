defmodule Demo.Core.User do
  import Demo.Helpers

  import Ecto.Changeset
  import Ecto.Query

  alias Demo.Core.Model.{Token, User}
  alias Demo.Core.Repo

  @type token :: String.t()

  defmacrop token_valid?(token) do
    quote do
      (unquote(token).type == :auth and unquote(token).inserted_at > ago(60, "day")) or
        (unquote(token).type == :confirm_email and unquote(token).inserted_at > ago(7, "day"))
    end
  end

  @doc """
  Registers a new user.

  On success, this function returns the new authentication token for the created user. The returned
  token is url-encoded. For security reasons, only the hash of the token is persisted in the
  database, while the raw value isn't stored anywhere.
  """
  @spec register(String.t(), String.t(), (token -> String.t())) ::
          :ok | {:error, Ecto.Changeset.t()}
  def register(email, password, url_fun) do
    Repo.transact(fn ->
      with {:ok, user} <- store_user(email, password) do
        token = create_token!(user, :confirm_email, %{email: user.email})

        Demo.Core.Mailer.send(
          user.email,
          "Activate your account",
          "Activate your account at #{url_fun.(token)}"
        )
      end
    end)
  end

  @spec confirm_email(token) :: {:ok, auth_token :: token} | :error
  def confirm_email(encoded) do
    Repo.transact(fn ->
      with {:ok, raw} <- Base.url_decode64(encoded, padding: false),
           %Token{} = token <- valid_token(token_hash(raw), :confirm_email) do
        user =
          Repo.one!(Ecto.assoc(token, :user))
          |> change(confirmed_at: DateTime.utc_now())
          |> Repo.update!()

        Repo.delete!(token)

        {:ok, create_token!(user, :auth)}
      else
        _ -> :error
      end
    end)
  end

  @spec from_auth_token(token) :: User.t() | nil
  def from_auth_token(encoded) do
    with {:ok, raw} <- Base.url_decode64(encoded, padding: false),
         %Token{} = token <- valid_token(token_hash(raw), :auth),
         user = Repo.one!(Ecto.assoc(token, :user)),
         :ok <- validate(user.confirmed_at != nil),
         do: user,
         else: (_ -> nil)
  end

  @spec delete_auth_token(token) :: :ok
  def delete_auth_token(encoded) do
    hash = encoded |> Base.url_decode64!(padding: false) |> token_hash()
    Repo.delete_all(where(Token, hash: ^hash, type: :auth))
    :ok
  end

  @spec delete_expired_tokens :: non_neg_integer()
  def delete_expired_tokens do
    {deleted_count, _} = Repo.delete_all(from(token in Token, where: not token_valid?(token)))
    deleted_count
  end

  defp store_user(email, password) do
    %User{}
    |> change(email: email)
    |> validate_email()
    |> change_password_hash(password)
    |> Repo.insert()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Repo)
    |> unique_constraint(:email)
  end

  defp change_password_hash(user_or_changeset, password) do
    changeset = change(user_or_changeset)

    with :ok <- validate(is_bitstring(password) and password != "", "can't be blank"),
         length = String.length(password),
         min_length = if(Demo.Helpers.mix_env() == :dev, do: 4, else: 12),
         max_length = 72,
         :ok <- validate(length >= min_length, "should be at least #{min_length} characters"),
         :ok <- validate(length <= max_length, "should be at most #{max_length} characters"),
         do: change(changeset, password_hash: Bcrypt.hash_pwd_salt(password)),
         else: ({:error, reason} -> changeset |> add_error(:password, reason))
  end

  defp create_token!(user, type, payload \\ %{}) do
    token = :crypto.strong_rand_bytes(32)

    # we're only storing the token hash, to prevent the people with the database access from the
    # unauthorized usage of the token
    Repo.insert!(%Token{user_id: user.id, type: type, hash: token_hash(token), payload: payload})

    Base.url_encode64(token, padding: false)
  end

  defp token_hash(token), do: :crypto.hash(:sha256, token)

  defp valid_token(hash, type) do
    Repo.one(
      from token in Token,
        where: token_valid?(token),
        where: [hash: ^hash, type: ^type]
    )
  end
end
