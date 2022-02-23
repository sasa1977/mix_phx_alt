# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Controller do
  use Demo.Interface.Controller

  import Demo.Helpers

  alias Demo.Core.{Token, User}
  alias Demo.Interface.User.Auth

  def welcome(conn, _params), do: render(conn, :welcome)

  # ------------------------------------------------------------------------
  # Registration
  # ------------------------------------------------------------------------

  def start_registration_form(conn, _params),
    do: render(conn, :start_registration, changeset: empty_changeset())

  def start_registration(conn, %{"user" => %{"email" => email}}) do
    case User.start_registration(email, &Routes.user_url(conn, :finish_registration_form, &1)) do
      :ok -> render(conn, :instructions_sent, email: email)
      {:error, changeset} -> render(conn, :start_registration, changeset: changeset)
    end
  end

  def finish_registration_form(conn, %{"token" => token}) do
    if Token.valid?(token, :confirm_email),
      do: render(conn, :finish_registration, token: token, changeset: empty_changeset()),
      else: {:error, :not_found}
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
    Token.delete(Auth.token(conn), :auth)

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

  def settings(conn, _params), do: render_form(conn)

  def change_password(conn, %{"password" => password}) do
    %{"current" => current, "new" => new} = password

    case User.change_password(conn.assigns.current_user, current, new) do
      {:ok, auth_token} ->
        conn
        |> put_flash(:info, "Password changed successfully.")
        |> on_authenticated(auth_token)

      {:error, changeset} ->
        render_form(conn, password_changeset: changeset)
    end
  end

  def start_email_change(conn, %{"change_email" => %{"email" => email, "password" => password}}) do
    case User.start_email_change(
           conn.assigns.current_user,
           email,
           password,
           &Routes.user_url(conn, :change_email, &1)
         ) do
      :ok -> render(conn, :instructions_sent, email: email)
      {:error, changeset} -> render_form(conn, email_changeset: changeset)
    end
  end

  def change_email(conn, %{"token" => token}) do
    case User.change_email(token) do
      {:ok, token} ->
        conn |> put_flash(:info, "Email changed successfully.") |> on_authenticated(token)

      :error ->
        {:error, :not_found}
    end
  end

  defp render_form(conn, assigns \\ []) do
    default_assigns = [password_changeset: empty_changeset(), email_changeset: empty_changeset()]
    render(conn, :settings, Keyword.merge(default_assigns, assigns))
  end

  # ------------------------------------------------------------------------
  # Password reset
  # ------------------------------------------------------------------------

  def start_password_reset_form(conn, _params),
    do: render(conn, :start_password_reset, changeset: empty_changeset())

  def start_password_reset(conn, %{"user" => %{"email" => email}}) do
    case User.start_password_reset(email, &"http://localhost:4000/reset_password/#{&1}") do
      :ok -> render(conn, :instructions_sent, email: email)
      {:error, changeset} -> render(conn, :start_password_reset, changeset: changeset)
    end
  end

  def reset_password_form(conn, %{"token" => token}) do
    if Token.valid?(token, :password_reset),
      do: render(conn, :reset_password, changeset: empty_changeset(), token: token),
      else: {:error, :not_found}
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
end
