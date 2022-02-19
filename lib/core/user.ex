defmodule Demo.Core.User do
  import Demo.Helpers

  import Ecto.Changeset
  import Ecto.Query

  alias Demo.Core.Model.{Token, User}
  alias Demo.Core.Repo

  @type confirm_email_token :: String.t()
  @type auth_token :: String.t()
  @type finish_registration_url_builder :: (confirm_email_token -> String.t())

  @doc """
  Starts the registration process.

      1. Creates the new confirm_email token.
      2. Sends the activation email to the user, unless the user is already registered.

  Note that this function doesn't create the user entry. Multiple different registrations can be
  created for the same email, but only one of them will succeed. In addition, this function will
  not tell the user that the email has already been taken. This approach prevents possible
  malicious impersonations, as well as enumeration and timing attacks.

  The rest of the data is provided in `finish_registration/2`. Most notably, this is the place
  where the user provides the password, which reduces the chances of impersonations (person owning
  the account is not the person with the access to the given email).
  """
  @spec start_registration(String.t(), finish_registration_url_builder) ::
          :ok | {:error, Ecto.Changeset.t()}
  def start_registration(email, url_fun) do
    with :ok <- validate_email(email) do
      # We'll only generate the token and send an e-mail if the user doesn't exist. This avoid
      # spamming registered users with unwanted mails. However, to prevent enumeration attacks,
      # this operation will always succeed, even if the email has been taken.
      unless Repo.exists?(where(User, email: ^email)) do
        token = create_token!(nil, :confirm_email, %{email: email})

        Demo.Core.Mailer.send(
          email,
          "Registration",
          "To create the account visit #{url_fun.(token)}"
        )
      end

      :ok
    end
  end

  @doc """
  Finishes the registration process.

  On success, this function creates the user entry and returns the auth token that can be used with
  `authenticate/1`. If the token is invalid or expired, or if the email has been taken, the
  function returns `:error`. We don't make distinctions between these scenarios to avoid leaking
  emails.
  """
  @spec finish_registration(confirm_email_token, String.t()) ::
          {:ok, auth_token} | :error | {:error, Ecto.Changeset.t()}
  def finish_registration(confirm_email_token, password) do
    Repo.transact(fn ->
      with {:ok, token} <- fetch_token(confirm_email_token, :confirm_email),
           :ok <- validate(token != nil),
           {:ok, user} <- store_user(Map.fetch!(token.payload, "email"), password) do
        # confirm_email is a one-time token, so we're deleting it now
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

  @spec authenticate(auth_token) :: User.t() | nil
  def authenticate(auth_token) do
    case fetch_token(auth_token, :auth) do
      {:ok, token} -> Repo.one!(Ecto.assoc(token, :user))
      :error -> nil
    end
  end

  @spec logout(auth_token) :: :ok
  def logout(auth_token) do
    Repo.delete_all(where(Token, hash: ^token_hash!(auth_token), type: :auth))
    :ok
  end

  @spec delete_expired_tokens :: non_neg_integer()
  def delete_expired_tokens do
    {deleted_count, _} = Repo.delete_all(invalid_tokens_query())
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
    token_bytes = :crypto.strong_rand_bytes(32)
    token = Base.url_encode64(token_bytes, padding: false)

    # we're only storing the token hash, to prevent the people with the database access from the
    # unauthorized usage of the token
    Repo.insert!(%Token{
      user_id: user && user.id,
      type: type,
      hash: token_hash!(token),
      payload: payload
    })

    token
  end

  defp token_hash!(token) do
    {:ok, hash} = token_hash(token)
    hash
  end

  defp token_hash(token) do
    with {:ok, token_bytes} <- Base.url_decode64(token, padding: false),
         do: {:ok, :crypto.hash(:sha256, token_bytes)}
  end

  defp fetch_token(token, type) do
    with {:ok, token_hash} <- token_hash(token),
         token = Repo.get_by(valid_tokens_query(), hash: token_hash, type: type),
         :ok <- validate(token != nil),
         do: {:ok, token}
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
end
