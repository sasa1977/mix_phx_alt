defmodule Demo.Core.User do
  import Demo.Helpers

  import Ecto.Changeset
  import Ecto.Query

  alias Demo.Core.Model.{Token, User}
  alias Demo.Core.Repo

  @type token :: String.t()

  @doc """
  Registers a new user.

  On success, this function returns the new authentication token for the created user. The returned
  token is url-encoded. For security reasons, only the hash of the token is persisted in the
  database, while the raw value isn't stored anywhere.
  """
  @spec register(String.t(), String.t()) :: {:ok, token} | {:error, Ecto.Changeset.t()}
  def register(email, password) do
    Repo.transact(fn ->
      with {:ok, user} <- store_user(email, password) do
        token = create_token!(user, :auth)
        {:ok, token}
      end
    end)
  end

  @spec from_auth_token(token) :: User.t() | nil
  def from_auth_token(encoded) do
    with {:ok, raw} <- Base.url_decode64(encoded, padding: false),
         %Token{} = token <-
           Repo.one(where(Token, hash: ^token_hash(raw), type: :auth) |> preload(:user)),
         :ok <- validate(Token.valid?(token)),
         do: token.user,
         else: (_ -> nil)
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

  defp create_token!(user, type) do
    token = :crypto.strong_rand_bytes(32)

    # we're only storing the token hash, to prevent the people with the database access from the
    # unauthorized usage of the token
    Repo.insert!(%Token{user_id: user.id, type: type, hash: token_hash(token)})

    Base.url_encode64(token, padding: false)
  end

  defp token_hash(token), do: :crypto.hash(:sha256, token)
end
