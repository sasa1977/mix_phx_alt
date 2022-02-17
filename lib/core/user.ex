defmodule Demo.Core.User do
  import Ecto.Changeset
  import Demo.Helpers

  alias Demo.Core.Model.User
  alias Demo.Core.Repo

  @spec register(String.t(), String.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register(email, password) do
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
         min_length = if(Demo.Config.mix_env() == :dev, do: 4, else: 12),
         max_length = 72,
         :ok <- validate(length >= min_length, "should be at least #{min_length} characters"),
         :ok <- validate(length <= max_length, "should be at most #{max_length} characters"),
         do: change(changeset, password_hash: Bcrypt.hash_pwd_salt(password)),
         else: ({:error, reason} -> changeset |> add_error(:password, reason))
  end
end
