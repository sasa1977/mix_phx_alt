defmodule Demo.Core.User do
  import Demo.Helpers

  import Demo.Helpers
  import Ecto.Changeset
  import Ecto.Query

  alias Demo.Core.Model.{Token, User}
  alias Demo.Core.Repo

  @type confirm_email_token :: String.t()
  @type auth_token :: String.t()
  @type password_reset_token :: String.t()

  @type url_builder(arg) :: (arg -> url :: String.t())

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
  @spec start_registration(String.t(), url_builder(confirm_email_token)) ::
          :ok | {:error, Ecto.Changeset.t()}
  def start_registration(email, url_fun) do
    with :ok <- validate_email(email) do
      create_email_confirm_token(
        email,
        "Registration",
        &"To create the account visit #{url_fun.(&1)}"
      )

      # To avoid enumeration attacks this function always succeeds if email is valid.
      # See `create_email_confirm_token` for details.
      :ok
    end
  end

  @spec start_email_change(User.t(), String.t(), String.t(), url_builder(confirm_email_token)) ::
          :ok | {:error, Ecto.Changeset.t()}
  def start_email_change(user, email, password, url_fun) do
    with :ok <- validate_email(email),
         :ok <-
           validate(email != user.email, add_error(empty_changeset(), :email, "is the same")),
         :ok <- validate_current_password(user, password, :password) do
      create_email_confirm_token(
        user,
        email,
        "Confirm email change",
        &"To use this email address click the following url:\n#{url_fun.(&1)}"
      )

      # To avoid enumeration attacks this function always succeeds if email is valid.
      # See `create_email_confirm_token` for details.
      :ok
    end
  end

  defp create_email_confirm_token(user \\ nil, email, subject, body_fun) do
    # We'll only generate the token and send an e-mail if the user doesn't exist to avoid
    # spamming registered users with unwanted mails. However, to prevent enumeration attacks,
    # this operation will always succeed, even if the email has been taken.
    unless Repo.exists?(where(User, email: ^email)) do
      token = create_token!(user, :confirm_email, %{email: email})
      Demo.Core.Mailer.send(email, subject, body_fun.(token))
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
  def finish_registration(token, password) do
    Repo.transact(fn ->
      with {:ok, token} <- spend_token(token, :confirm_email),
           :ok <- validate(token.user == nil),
           {:ok, user} <-
             %User{}
             |> change_email(Map.fetch!(token.payload, "email"))
             |> change_password_hash(password)
             |> Repo.insert(),
           do: {:ok, create_token!(user, :auth)}
    end)
    |> anonymize_email_exists_error()
  end

  defp change_email(user, email),
    do: user |> change(email: email) |> unique_constraint(:email)

  defp anonymize_email_exists_error(outcome) do
    with {:error, %Ecto.Changeset{errors: errors}} <- outcome,
         {"has already been taken", _} <- Keyword.get(errors, :email),
         do: :error,
         else: (_ -> outcome)
  end

  @spec login(String.t(), String.t()) :: {:ok, auth_token} | :error
  def login(email, password) do
    user = Repo.get_by(User, email: email)

    password_valid? =
      if user != nil,
        do: Bcrypt.verify_pass(password, user.password_hash),
        else: Bcrypt.no_user_verify()

    if password_valid?,
      do: {:ok, create_token!(user, :auth)},
      else: :error
  end

  @spec authenticate(auth_token) :: User.t() | nil
  def authenticate(auth_token) do
    case fetch_token(auth_token, :auth) do
      {:ok, token} -> token.user
      :error -> nil
    end
  end

  @spec logout(auth_token) :: :ok
  def logout(auth_token) do
    Repo.delete_all(where(Token, hash: ^ok!(token_hash(auth_token)), type: :auth))
    :ok
  end

  @spec start_password_reset(String.t(), url_builder(password_reset_token)) ::
          :ok | {:error, Ecto.Changeset.t()}
  def start_password_reset(email, url_fun) do
    with :ok <- validate_email(email) do
      if user = Repo.one(User, email: email) do
        token = create_token!(user, :password_reset)

        Demo.Core.Mailer.send(
          email,
          "Password reset",
          "You can reset the password at the following url:\n#{url_fun.(token)}"
        )
      end

      # To prevent enumeration attacks, this operation will always succeed, even if the email doesn't exist.
      :ok
    end
  end

  @spec reset_password(password_reset_token, String.t()) ::
          {:ok, auth_token} | :error | {:error, Ecto.Changeset.t()}
  def reset_password(token, password) do
    Repo.transact(fn ->
      with {:ok, token} <- fetch_token(token, :password_reset),
           {:ok, user} <- token.user |> change_password_hash(password) |> Repo.update() do
        # delete the token so it can't be used again
        Repo.delete(token)
        {:ok, create_token!(user, :auth)}
      end
    end)
  end

  @spec change_password(User.t(), String.t(), String.t()) ::
          {:ok, auth_token} | {:error, Ecto.Changeset.t()}
  def change_password(user, current, new) do
    with :ok <- validate_current_password(user, current, :current),
         {:ok, new_password_hash} <- validate_password_change(user, new),
         {:ok, user} <- safe_update_password_hash(user, new_password_hash) do
      # Since the password has been changed, we'll delete all other user's tokens. We're
      # deliberately doing this outside of the transaction to make sure that login attempts with
      # the old password won't succeed (since the hash update has been comitted at this point).
      Repo.delete_all(where(Token, user_id: ^user.id))
      {:ok, create_token!(user, :auth)}
    end
  end

  defp validate_password_change(user, new) do
    changeset = change_password_hash(user, new, field_name: :new)

    case apply_action(changeset, :update) do
      {:ok, user} -> {:ok, user.password_hash}
      {:error, changeset} -> {:error, transfer_changeset_errors(changeset, empty_changeset())}
    end
  end

  defp validate_current_password(user, password, field_name) do
    validate(
      Bcrypt.verify_pass(password, user.password_hash),
      add_error(empty_changeset(), field_name, "is not valid")
    )
  end

  defp safe_update_password_hash(user, new_password_hash) do
    # Using update_all and filtering by password hash to make sure that the password hasn't
    # been changed after the user has been loaded from the database.
    case Repo.update_all(
           from(user in User,
             where: [id: ^user.id, password_hash: ^user.password_hash],
             select: user
           ),
           set: [password_hash: new_password_hash]
         ) do
      {1, [user]} -> {:ok, user}
      {0, _} -> {:error, add_error(empty_changeset(), :current, "is not valid")}
    end
  end

  @spec validate_token(String.t(), Token.type()) :: :ok | :error
  def validate_token(token, type) do
    with {:ok, hash} <- token_hash(token),
         do: validate(Repo.exists?(valid_tokens_query(), hash: hash, type: type))
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

  defp change_password_hash(user_or_changeset, password, opts \\ []) do
    field_name = Keyword.get(opts, :field_name, :password)
    changeset = change(user_or_changeset)

    with :ok <- validate(is_bitstring(password) and password != "", "can't be blank"),
         length = String.length(password),
         min_length = if(Demo.Helpers.mix_env() == :dev, do: 4, else: 12),
         max_length = 72,
         :ok <- validate(length >= min_length, "should be at least #{min_length} characters"),
         :ok <- validate(length <= max_length, "should be at most #{max_length} characters"),
         do: change(changeset, password_hash: Bcrypt.hash_pwd_salt(password)),
         else: ({:error, reason} -> changeset |> add_error(field_name, reason))
  end

  defp create_token!(user, type, payload \\ %{}) do
    token_bytes = :crypto.strong_rand_bytes(32)
    token = Base.url_encode64(token_bytes, padding: false)

    # we're only storing the token hash, to prevent the people with the database access from the
    # unauthorized usage of the token
    Repo.insert!(%Token{
      user_id: user && user.id,
      type: type,
      hash: ok!(token_hash(token)),
      payload: payload
    })

    token
  end

  defp token_hash(token) do
    with {:ok, token_bytes} <- Base.url_decode64(token, padding: false),
         do: {:ok, :crypto.hash(:sha256, token_bytes)}
  end

  defp spend_token(token, type) do
    fetch_token(token, type)
    |> tap(&with {:ok, token} <- &1, do: Repo.delete(token))
  end

  defp fetch_token(token, type) do
    with {:ok, token_hash} <- token_hash(token),
         token = Repo.get_by(preload(valid_tokens_query(), :user), hash: token_hash, type: type),
         :ok <- validate(token != nil),
         do: {:ok, token}
  end

  defp delete_expired_tokens do
    {deleted_count, _} = Repo.delete_all(invalid_tokens_query())
    deleted_count
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

  @doc false
  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(_arg), do: token_cleanup()

  defp token_cleanup do
    Periodic.child_spec(
      id: __MODULE__.TokenCleanup,
      name: __MODULE__.TokenCleanup,
      every: :timer.hours(1),
      on_overlap: :stop_previous,
      run: &delete_expired_tokens/0,
      mode: if(Demo.Helpers.mix_env() == :test, do: :manual, else: :auto)
    )
  end
end
