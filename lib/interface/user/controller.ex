# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Controller do
  use Demo.Interface.Controller

  alias Demo.Core.{Model, User}
  alias Demo.Interface.User.Auth

  def welcome(conn, _params), do: render(conn, :welcome)

  # ------------------------------------------------------------------------
  # Registration
  # ------------------------------------------------------------------------

  def start_registration_form(conn, _params),
    do: render(conn, :start_registration, changeset: user_changeset())

  def start_registration(conn, %{"user" => %{"email" => email}}) do
    case User.start_registration(email, &Routes.user_url(conn, :finish_registration_form, &1)) do
      :ok -> render(conn, :instructions_sent, email: email)
      {:error, changeset} -> render(conn, :start_registration, changeset: changeset)
    end
  end

  def finish_registration_form(conn, %{"token" => token}) do
    case User.validate_token(token, :confirm_email) do
      :ok -> render(conn, :finish_registration, token: token, changeset: user_changeset())
      :error -> {:error, :not_found}
    end
  end

  def finish_registration(conn, %{"token" => token, "user" => %{"password" => password}}) do
    case User.finish_registration(token, password) do
      {:ok, token} ->
        conn |> put_flash(:info, "User activated successfully.") |> on_authenticated(token)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :finish_registration, token: token, changeset: changeset)

      :error ->
        {:error, :not_found}
    end
  end

  # ------------------------------------------------------------------------
  # Authentication
  # ------------------------------------------------------------------------

  def login_form(conn, _params),
    do: render(conn, :login, error_message: nil)

  def login(conn, %{"user" => user}) do
    %{"email" => email, "password" => password, "remember" => remember?} = user

    case User.login(email, password) do
      {:ok, token} -> on_authenticated(conn, token, remember?: remember? == "true")
      :error -> render(conn, :login, error_message: "Invalid email or password")
    end
  end

  def logout(conn, _params) do
    User.logout(Auth.token(conn))

    conn
    |> Auth.clear()
    |> redirect(to: Routes.user_path(conn, :login_form))
  end

  defp on_authenticated(conn, auth_token, opts \\ []) do
    conn
    |> Auth.set(auth_token, opts)
    |> redirect(to: Routes.user_path(conn, :welcome))
  end

  # ------------------------------------------------------------------------
  # Settings
  # ------------------------------------------------------------------------

  def settings(conn, _params) do
    render(conn, :settings,
      password_changeset: Ecto.Changeset.change({%{}, %{current: :string, new: :string}})
    )
  end

  def change_password(conn, %{"password" => password}) do
    %{"current" => current, "new" => new} = password

    case User.change_password(conn.assigns.current_user, current, new) do
      {:ok, auth_token} ->
        conn
        |> put_flash(:info, "Password changed successfully.")
        |> on_authenticated(auth_token)

      {:error, changeset} ->
        render(conn, :settings, password_changeset: changeset)
    end
  end

  # ------------------------------------------------------------------------
  # Password reset
  # ------------------------------------------------------------------------

  def start_password_reset_form(conn, _params),
    do: render(conn, :start_password_reset, changeset: user_changeset())

  def start_password_reset(conn, %{"user" => %{"email" => email}}) do
    case User.start_password_reset(email, &"http://localhost:4000/reset_password/#{&1}") do
      :ok -> render(conn, :instructions_sent, email: email)
      {:error, changeset} -> render(conn, :start_password_reset, changeset: changeset)
    end
  end

  def reset_password_form(conn, %{"token" => token}) do
    case User.validate_token(token, :password_reset) do
      :ok -> render(conn, :reset_password, changeset: user_changeset(), token: token)
      :error -> {:error, :not_found}
    end
  end

  def reset_password(conn, %{"token" => token, "user" => %{"password" => password}}) do
    case User.reset_password(token, password) do
      {:ok, token} ->
        conn |> put_flash(:info, "Password changed successfully.") |> on_authenticated(token)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :reset_password, changeset: changeset, token: token)

      :error ->
        {:error, :not_found}
    end
  end

  # ------------------------------------------------------------------------
  # Common
  # ------------------------------------------------------------------------

  defp user_changeset, do: Ecto.Changeset.change(%Model.User{})
end
