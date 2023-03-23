# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Controller do
  use Demo.Interface.Base.Controller

  import Demo.Helpers

  alias Demo.Core.{Token, User}
  alias Demo.Interface.User.Auth

  plug :require_anonymous
       when action in ~w/
        start_registration_form start_registration
        finish_registration_form finish_registration
        login_form login
        start_password_reset_form start_password_reset/a

  plug :require_user
       when action in ~w/welcome logout settings change_password start_email_change/a

  def welcome(conn, _params), do: render(conn, :welcome)

  # ------------------------------------------------------------------------
  # Registration
  # ------------------------------------------------------------------------

  def start_registration_form(conn, _params),
    do: render(conn, :start_registration, changeset: empty_changeset())

  def start_registration(conn, params) do
    email = params |> Map.fetch!("form") |> Map.fetch!("email")

    case User.start_registration(email) do
      :ok -> render(conn, :instructions_sent, email: email)
      {:error, changeset} -> render(conn, :start_registration, changeset: changeset)
    end
  end

  def finish_registration_form(conn, params) do
    token = Map.fetch!(params, "token")

    if Token.valid?(token, :confirm_email),
      do: render(conn, :finish_registration, token: token, changeset: empty_changeset()),
      else: {:error, :not_found}
  end

  def finish_registration(conn, params) do
    token = Map.fetch!(params, "token")
    password = params |> Map.fetch!("form") |> Map.fetch!("password")

    case User.finish_registration(token, password) do
      {:ok, token} ->
        conn |> put_flash(:info, "User activated successfully.") |> on_authenticated(token)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :finish_registration, token: token, changeset: changeset)

      {:error, :invalid_token} ->
        {:error, :not_found}
    end
  end

  # ------------------------------------------------------------------------
  # Authentication
  # ------------------------------------------------------------------------

  def login_form(conn, _params),
    do: render(conn, :login, error_message: nil)

  def login(conn, params) do
    %{"form" => %{"email" => email, "password" => password, "remember" => remember?}} = params

    case User.login(email, password) do
      {:ok, token} -> on_authenticated(conn, token, remember?: remember? == "true")
      :error -> render(conn, :login, error_message: "Invalid email or password")
    end
  end

  def logout(conn, _params) do
    Token.delete(Auth.token(conn), :auth)

    conn
    |> Auth.clear()
    |> redirect(to: ~p"/login_form")
  end

  defp on_authenticated(conn, auth_token, opts \\ []) do
    conn
    |> Auth.set(auth_token, opts)
    |> redirect(to: ~p"/")
  end

  # ------------------------------------------------------------------------
  # Settings
  # ------------------------------------------------------------------------

  def settings(conn, _params), do: render_form(conn)

  def change_password(conn, params) do
    %{"password" => %{"current" => current, "new" => new}} = params

    case User.change_password(conn.assigns.current_user, current, new) do
      {:ok, auth_token} ->
        conn
        |> put_flash(:info, "Password changed successfully.")
        |> on_authenticated(auth_token)

      {:error, changeset} ->
        render_form(conn, password_changeset: changeset)
    end
  end

  def start_email_change(conn, params) do
    %{"change_email" => %{"email" => email, "password" => password}} = params

    case User.start_email_change(conn.assigns.current_user, email, password) do
      :ok -> render(conn, :instructions_sent, email: email)
      {:error, changeset} -> render_form(conn, email_changeset: changeset)
    end
  end

  def change_email(conn, params) do
    token = Map.fetch!(params, "token")

    case User.change_email(token) do
      {:ok, token} ->
        conn |> put_flash(:info, "Email changed successfully.") |> on_authenticated(token)

      {:error, :invalid_token} ->
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

  def start_password_reset(conn, params) do
    email = params |> Map.fetch!("form") |> Map.fetch!("email")

    case User.start_password_reset(email) do
      :ok -> render(conn, :instructions_sent, email: email)
      {:error, changeset} -> render(conn, :start_password_reset, changeset: changeset)
    end
  end

  def reset_password_form(conn, params) do
    token = Map.fetch!(params, "token")

    if Token.valid?(token, :password_reset),
      do:
        render(conn, :reset_password,
          changeset: empty_changeset(),
          token: token,
          error_message: nil
        ),
      else: {:error, :not_found}
  end

  def reset_password(conn, params) do
    token = Map.fetch!(params, "token")
    password = params |> Map.fetch!("form") |> Map.fetch!("password")

    case User.reset_password(token, password) do
      {:ok, token} ->
        conn |> put_flash(:info, "Password changed successfully.") |> on_authenticated(token)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :reset_password, changeset: changeset, token: token, error_message: nil)

      {:error, :invalid_token} ->
        {:error, :not_found}
    end
  end
end
