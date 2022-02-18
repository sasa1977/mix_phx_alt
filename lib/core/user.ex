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
        (unquote(token).type == :activation and unquote(token).inserted_at > ago(7, "day"))
    end
  end

  @doc """
  Registers a new user.

  This function will validate the input and send the activation mail. However, the user record
  will only be created on successful activation.

  As a result, multiple people can attempt to register with the same e-mail address, but only one
  such registration will succeed.
  """
  @spec register(String.t(), (token -> String.t())) :: :ok | {:error, Ecto.Changeset.t()}
  def register(email, url_fun) do
    with :ok <- validate_email(email) do
      # We'll only generate the token and send an e-mail if the user doesn't exist. This avoid
      # spamming registered users with unwanted mails. However, to prevent enumeration attacks,
      # this operation will always succeed, even if the email has been taken.
      unless Repo.exists?(where(User, email: ^email)) do
        token = create_token!(nil, :activation, %{email: email})

        Demo.Core.Mailer.send(
          email,
          "Activate your account",
          "Activate your account at #{url_fun.(token)}"
        )
      end

      :ok
    end
  end

  @doc """
  Creates and activates the user.

  On success the function will also create an auth token and return it.
  If the activation token is invalid or the email has already been taken the function returns `:error`.
  If the submitted data is invalid, the function will return corresponding errors as a changeset.
  """
  @spec activate(token, String.t()) ::
          {:ok, auth_token :: token} | :error | {:error, Ecto.Changeset.t()}
  def activate(encoded, password) do
    Repo.transact(fn ->
      with {:ok, raw} <- Base.url_decode64(encoded, padding: false),
           token = valid_token(token_hash(raw), :activation),
           validate(token != nil),
           {:ok, user} <- store_user(Map.fetch!(token.payload, "email"), password) do
        # activation is a one-time token, so we're deleting it now
        Repo.delete(token)
        {:ok, create_token!(user, :auth)}
      end
    end)
    |> then(
      # convert "email has already been taken" into a generic error, because the user can't do anything at this point
      &with {:error, %Ecto.Changeset{errors: errors}} <- &1,
            {"has already been taken", _} <- Keyword.get(errors, :email),
            do: :error,
            else: (_ -> &1)
    )
  end

  @spec from_auth_token(token) :: User.t() | nil
  def from_auth_token(encoded) do
    with {:ok, raw} <- Base.url_decode64(encoded, padding: false),
         %Token{} = token <- valid_token(token_hash(raw), :auth),
         do: Repo.one!(Ecto.assoc(token, :user)),
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
    |> change_password_hash(password)
    |> unique_constraint(:email)
    |> Repo.insert()
  end

  defp validate_email(email) do
    with {:ok, _} <-
           %User{}
           |> change(email: email)
           |> validate_required([:email])
           |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
             message: "must have the @ sign and no spaces"
           )
           |> validate_length(:email, max: 160)
           |> apply_action(:insert),
         do: :ok
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
    Repo.insert!(%Token{
      user_id: user && user.id,
      type: type,
      hash: token_hash(token),
      payload: payload
    })

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
