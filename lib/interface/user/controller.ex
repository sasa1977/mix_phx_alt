# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Controller do
  use Demo.Interface.Controller
  alias Demo.Core.{Model, User}

  def welcome(conn, _params), do: render(conn, :welcome)

  # ------------------------------------------------------------------------
  # Registration
  # ------------------------------------------------------------------------

  def start_registration_form(conn, _params),
    do: render(conn, :start_registration, changeset: Ecto.Changeset.change(%Model.User{}))

  def start_registration(conn, %{"user" => %{"email" => email}}) do
    case User.start_registration(email, &Routes.user_url(conn, :finish_registration_form, &1)) do
      :ok -> render(conn, :activation_pending, email: email)
      {:error, changeset} -> render(conn, :start_registration, changeset: changeset)
    end
  end

  def finish_registration_form(conn, %{"token" => token}) do
    conn
    |> put_session(:confirm_email_token, token)
    |> render(:finish_registration, changeset: Ecto.Changeset.change(%Model.User{}))
  end

  def finish_registration(conn, %{"user" => %{"password" => password}}) do
    case User.finish_registration(get_session(conn, :confirm_email_token), password) do
      {:ok, token} ->
        conn |> put_flash(:info, "User activated successfully.") |> on_authenticated(token)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :finish_registration, changeset: changeset)

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
    %{"email" => email, "password" => password, "remember_me" => remember_me?} = user

    case User.login(email, password) do
      {:ok, token} -> on_authenticated(conn, token, remember_me?: remember_me? == "true")
      :error -> render(conn, :login, error_message: "Invalid email or password")
    end
  end

  def logout(conn, _params) do
    conn |> get_session(:auth_token) |> User.logout()

    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> delete_resp_cookie("auth_token")
    |> assign(:current_user, nil)
    |> redirect(to: Routes.user_path(conn, :login_form))
  end

  defp on_authenticated(conn, auth_token, opts \\ []) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> delete_resp_cookie("auth_token")
    |> put_session(:auth_token, auth_token)
    |> then(fn conn ->
      if Keyword.get(opts, :remember_me?, false) do
        put_resp_cookie(conn, "auth_token", auth_token,
          sign: true,
          max_age: Model.Token.validity(:auth) * 24 * 60 * 60,
          same_site: "Lax"
        )
      else
        conn
      end
    end)
    |> redirect(to: Routes.user_path(conn, :welcome))
  end
end
