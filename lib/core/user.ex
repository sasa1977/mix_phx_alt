defmodule Demo.Core.User do
  import Demo.Helpers
  import Ecto.Changeset
  import Ecto.Query

  alias Demo.Core.{Model.User, Repo, Token}

  @type confirm_email_token :: Token.t()
  @type auth_token :: Token.t()
  @type password_reset_token :: Token.t()

  @type url_builder(arg) :: (arg -> url :: String.t())

  @spec start_registration(String.t(), url_builder(confirm_email_token)) ::
          :ok | {:error, Ecto.Changeset.t()}
  def start_registration(email, url_fun) do
    with {:ok, _} <-
           changeset(email: :string)
           |> change(email: email)
           |> validate_email()
           |> apply_action(:insert) do
      # Note that we don't create the user entry here. Multiple different registrations can be
      # started for the same email, but only one can succeed. This prevents hijacking the
      # registration for a non-owned email. See `create_email_confirmation` for details.
      create_email_confirmation(
        email,
        "Registration",
        &"To create the account visit #{url_fun.(&1)}"
      )
    end
  end

  @spec finish_registration(confirm_email_token, String.t()) ::
          {:ok, auth_token} | :error | {:error, Ecto.Changeset.t()}
  def finish_registration(token, password) do
    Repo.transact(fn ->
      with {:ok, token} <- Token.spend(token, :confirm_email),
           :ok <- validate(token.user == nil),
           {:ok, user} <-
             %User{}
             |> change_email(Map.fetch!(token.payload, "email"))
             |> change_password_hash(password)
             |> Repo.insert(),
           do: {:ok, Token.create(user, :auth)}
    end)
    |> anonymize_email_exists_error()
  end

  @spec start_email_change(User.t(), String.t(), String.t(), url_builder(confirm_email_token)) ::
          :ok | {:error, Ecto.Changeset.t()}
  def start_email_change(user, email, password, url_fun) do
    with {:ok, _} <-
           changeset(email: :string, password: :string)
           |> change(email: email, password: password)
           |> validate_email()
           |> validate_field(:email, &(&1 != user.email), "is the same")
           |> validate_field(:password, &password_ok?(user, &1), "is invalid")
           |> apply_action(:update) do
      create_email_confirmation(
        user,
        email,
        "Confirm email change",
        &"To use this email address click the following url:\n#{url_fun.(&1)}"
      )
    end
  end

  @spec change_email(confirm_email_token) :: {:ok, auth_token} | :error
  def change_email(token) do
    Repo.transact(fn ->
      with {:ok, token} <- Token.spend(token, :confirm_email),
           :ok <- validate(token.user != nil),
           {:ok, user} <-
             token.user
             |> change_email(Map.fetch!(token.payload, "email"))
             |> Repo.update() do
        Token.delete_all(user)
        {:ok, Token.create(user, :auth)}
      end
    end)
    |> anonymize_email_exists_error()
  end

  defp create_email_confirmation(user \\ nil, email, subject, body_fun) do
    # We'll only generate the token and send an e-mail if the user doesn't exist to avoid spamming
    # registered users with unwanted mails.
    #
    # Furthermore, we don't check for the email uniqueness. Multiple confirm tokens can be created
    # for the same e-mail, by the same user, or by multiple users. This allows retries, and
    # prevents hijacking of non-owned emails, when a user tries to confirm the email address they
    # don't own.
    unless Repo.exists?(where(User, email: ^email)) do
      token = Token.create(user, :confirm_email, %{email: email})
      Demo.Core.Mailer.send(email, subject, body_fun.(token))
    end

    # To prevent enumeration attacks, this operation will always succeed, even if the email has been taken.
    :ok
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

    if password_ok?(user, password),
      do: {:ok, Token.create(user, :auth)},
      else: :error
  end

  @spec start_password_reset(String.t(), url_builder(password_reset_token)) ::
          :ok | {:error, Ecto.Changeset.t()}
  def start_password_reset(email, url_fun) do
    with {:ok, _} <-
           changeset(email: :string)
           |> change(email: email)
           |> validate_email()
           |> apply_action(:update) do
      if user = Repo.one(User, email: email) do
        token = Token.create(user, :password_reset)

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
      with {:ok, token} <- Token.fetch(token, :password_reset),
           {:ok, user} <- token.user |> change_password_hash(password) |> Repo.update() do
        # delete the token so it can't be used again
        Repo.delete(token)
        {:ok, Token.create(user, :auth)}
      end
    end)
  end

  @spec change_password(User.t(), String.t(), String.t()) ::
          {:ok, auth_token} | {:error, Ecto.Changeset.t()}
  def change_password(user, current, new) do
    with {:ok, %{password_hash: new_password_hash}} <-
           changeset(password_hash: :binary, current: :string)
           |> change(current: current)
           |> validate_field(:current, &password_ok?(user, &1), "is invalid")
           |> change_password_hash(new, field_name: :new)
           |> apply_action(:update),
         {:ok, user} <- safe_update_password_hash(user, new_password_hash) do
      # Since the password has been changed, we'll delete all other user's tokens. We're
      # deliberately doing this outside of the transaction to make sure that login attempts with
      # the old password won't succeed (since the hash update has been comitted at this point).
      Token.delete_all(user)
      {:ok, Token.create(user, :auth)}
    end
  end

  defp password_ok?(user, password) do
    if user != nil,
      do: Bcrypt.verify_pass(password, user.password_hash),
      else: Bcrypt.no_user_verify()
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
      {1, [user]} ->
        {:ok, user}

      {0, _} ->
        changeset(current: :string)
        |> add_error(:current, "is not valid")
        |> apply_action(:update)
    end
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
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
end
