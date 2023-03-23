defmodule Demo.Core.User do
  import Demo.Helpers
  import Ecto.Changeset
  import Ecto.Query

  alias Demo.Core.{Model.User, Repo, Token, UrlBuilder}

  @type confirm_email_token :: Token.value()
  @type auth_token :: Token.value()
  @type password_reset_token :: Token.value()

  @spec start_registration(String.t()) :: :ok | {:error, Ecto.Changeset.t()}
  def start_registration(email) do
    with :ok <- validate_email_shape(email) do
      # Note that we don't create the user entry here. Multiple different registrations can be
      # started for the same email, but only one can succeed. This prevents hijacking the
      # registration for a non-owned email. See `create_email_confirmation` for details.
      create_email_confirmation(
        email,
        "Registration",
        &"To create the account visit #{UrlBuilder.finish_registration_form(&1)}"
      )
    end
  end

  @spec finish_registration(confirm_email_token, String.t()) ::
          {:ok, auth_token} | {:error, :invalid_token | Ecto.Changeset.t()}
  def finish_registration(token, password) do
    Repo.transact(fn ->
      with {:ok, token} <- Token.spend(token, :confirm_email),
           :ok <- validate(token.user == nil, :invalid_token),
           email = Map.fetch!(token.payload, "email"),
           {:ok, user} <- insert_user(email, password),
           do: {:ok, Token.create(user, :auth)}
    end)
  end

  defp insert_user(email, password) do
    %User{}
    |> set_email(email)
    |> set_password(password)
    |> Repo.insert()
    |> anonymize_email_exists_error()
  end

  @spec start_email_change(User.t(), String.t(), String.t()) ::
          :ok | {:error, Ecto.Changeset.t()}
  def start_email_change(user, email, password) do
    with {:ok, _} <-
           {%{}, %{email: :string, password: :string}}
           |> change(email: email, password: password)
           |> validate_email_shape()
           |> validate_field(:email, &if(&1 == user.email, do: "is the same"))
           |> validate_field(:password, &unless(password_ok?(user, &1), do: "is incorrect"))
           |> apply_action(:update) do
      create_email_confirmation(
        user,
        email,
        "Confirm email change",
        &"To use this email address click the following url:\n#{UrlBuilder.change_email(&1)}"
      )
    end
  end

  @spec change_email(confirm_email_token) :: {:ok, auth_token} | {:error, :invalid_token}
  def change_email(token) do
    with {:ok, user} <-
           Repo.transact(fn ->
             with {:ok, token} <- Token.spend(token, :confirm_email),
                  :ok <- validate(token.user != nil, :invalid_token) do
               token.user
               |> set_email(Map.fetch!(token.payload, "email"))
               |> Repo.update()
               |> anonymize_email_exists_error()
             end
           end) do
      # Since the email has been changed, we'll delete all other user's tokens. We're
      # deliberately doing this outside of the transaction to make sure that login attempts with
      # the old email won't succeed (since the hash update has been comitted at this point).
      Token.delete_all(user)
      {:ok, Token.create(user, :auth)}
    end
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

  defp set_email(user, email),
    do: user |> change(email: email) |> unique_constraint(:email)

  defp anonymize_email_exists_error(outcome) do
    with {:error, %Ecto.Changeset{errors: errors}} <- outcome,
         {"has already been taken", _} <- Keyword.get(errors, :email),
         do: {:error, :invalid_token},
         else: (_ -> outcome)
  end

  @spec login(String.t(), String.t()) :: {:ok, auth_token} | :error
  def login(email, password) do
    user = Repo.get_by(User, email: email)

    if password_ok?(user, password),
      do: {:ok, Token.create(user, :auth)},
      else: :error
  end

  @spec start_password_reset(String.t()) :: :ok | {:error, Ecto.Changeset.t()}
  def start_password_reset(email) do
    with :ok <- validate_email_shape(email) do
      if user = Repo.get_by(User, email: email) do
        token = Token.create(user, :password_reset)

        Demo.Core.Mailer.send(
          email,
          "Password reset",
          "You can reset the password at the following url:\n#{UrlBuilder.reset_password_form(token)}"
        )
      end

      # To prevent enumeration attacks, this operation will always succeed, even if the email doesn't exist.
      :ok
    end
  end

  @spec reset_password(password_reset_token, String.t()) ::
          {:ok, auth_token} | {:error, :invalid_token | Ecto.Changeset.t()}
  def reset_password(token, password) do
    with {:ok, user} <-
           Repo.transact(fn ->
             with {:ok, token} <- Token.spend(token, :password_reset),
                  do: token.user |> set_password(password) |> Repo.update()
           end) do
      # Since the password has been changed, we'll delete all other user's tokens. We're
      # deliberately doing this outside of the transaction to make sure that login attempts with
      # the old password won't succeed (since the hash update has been comitted at this point).
      Token.delete_all(user)
      {:ok, Token.create(user, :auth)}
    end
  end

  @spec change_password(User.t(), String.t(), String.t()) ::
          {:ok, auth_token} | {:error, Ecto.Changeset.t()}
  def change_password(user, current, new) do
    with {:ok, user} <-
           Repo.transact(fn ->
             # refreshing the user and locking it, to ensure we're checking the latest password
             Repo.one!(from User, where: [id: ^user.id], lock: "FOR UPDATE")
             |> change()
             |> then(fn changeset ->
               if password_ok?(user, current),
                 do: changeset,
                 else: add_error(changeset, :current, "is incorrect")
             end)
             |> set_password(new, error_as: :new)
             |> Repo.update()
           end) do
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

  defp password_hash(password), do: Bcrypt.hash_pwd_salt(password)

  @spec validate_email_shape(String.t()) :: :ok | {:error, Ecto.Changeset.t()}
  @spec validate_email_shape(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_email_shape(email) when is_binary(email) do
    with {:ok, _map} <-
           {%{}, %{email: :string}}
           |> change(email: email)
           |> validate_email_shape()
           |> apply_action(:insert),
         do: :ok
  end

  defp validate_email_shape(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
  end

  defp set_password(user_schema_or_changeset, value, opts \\ []) do
    error_field = Keyword.get(opts, :error_as, :password)
    min_length = if(Demo.Helpers.mix_env() == :dev, do: 4, else: 12)

    {%{}, %{error_field => :string}}
    |> change([{error_field, value}])
    |> validate_required(error_field)
    |> validate_length(error_field, min: min_length, max: 72)
    |> apply_action(:insert)
    |> case do
      {:ok, _} ->
        change(user_schema_or_changeset, password_hash: password_hash(value))

      {:error, error_changeset} ->
        transfer_errors(error_changeset, change(user_schema_or_changeset))
    end
  end

  defp transfer_errors(from_changeset, to_changeset) do
    Enum.reduce(
      from_changeset.errors,
      to_changeset,
      fn {field, {error, keys}}, changeset ->
        Ecto.Changeset.add_error(changeset, field, error, keys)
      end
    )
  end
end
