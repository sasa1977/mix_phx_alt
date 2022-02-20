# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Controller do
  use Demo.Interface.Controller
  alias Demo.Core.{Model, User}

  def welcome(conn, _params), do: render(conn, :welcome)

  def start_registration_form(conn, _params),
    do: render(conn, :start_registration_form, changeset: Ecto.Changeset.change(%Model.User{}))

  def start_registration(conn, %{"user" => %{"email" => email}}) do
    case User.start_registration(email, &Routes.user_url(conn, :finish_registration_form, &1)) do
      :ok -> render(conn, :activation_pending, email: email)
      {:error, changeset} -> render(conn, :start_registration_form, changeset: changeset)
    end
  end

  def finish_registration_form(conn, %{"token" => token}) do
    conn
    |> put_session(:confirm_email_token, token)
    |> render(:finish_registration_form, changeset: Ecto.Changeset.change(%Model.User{}))
  end

  def finish_registration(conn, %{"user" => %{"password" => password}}) do
    case User.finish_registration(get_session(conn, :confirm_email_token), password) do
      {:ok, token} ->
        conn
        |> clear_session()
        |> put_session(:auth_token, token)
        |> put_flash(:info, "User activated successfully.")
        |> redirect(to: Routes.user_path(conn, :welcome))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :finish_registration_form, changeset: changeset)

      :error ->
        {:error, :not_found}
    end
  end

  def login_form(conn, _params),
    do: render(conn, :login_form, error_message: nil)

  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case User.login(email, password) do
      {:ok, token} ->
        conn
        |> clear_session()
        |> put_session(:auth_token, token)
        |> redirect(to: Routes.user_path(conn, :welcome))

      :error ->
        render(conn, :login_form, error_message: "Invalid email or password")
    end
  end

  def logout(conn, _params) do
    conn |> get_session(:auth_token) |> User.logout()

    conn
    |> clear_session()
    |> assign(:current_user, nil)
    |> redirect(to: Routes.user_path(conn, :login_form))
  end
end
