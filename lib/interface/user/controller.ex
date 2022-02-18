# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Controller do
  use Demo.Interface.Controller
  alias Demo.Core.{Model, User}

  def welcome(conn, _params), do: render(conn, :welcome)

  def registration_form(conn, _params),
    do: render(conn, :registration_form, changeset: Ecto.Changeset.change(%Model.User{}))

  def register(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case User.register(email, password, &Routes.user_url(conn, :confirm_email, &1)) do
      :ok ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: Routes.user_path(conn, :registration_form))

      {:error, changeset} ->
        render(conn, :registration_form, changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case User.confirm_email(token) do
      {:ok, token} ->
        conn
        |> put_session(:user_token, token)
        |> put_flash(:info, "User activated successfully.")
        |> redirect(to: Routes.user_path(conn, :welcome))

      :error ->
        text(conn, "Activation error")
    end
  end

  def logout(conn, _params) do
    conn |> get_session(:user_token) |> User.delete_auth_token()

    conn
    |> clear_session()
    |> assign(:current_user, nil)
    |> redirect(to: Routes.user_path(conn, :registration_form))
  end
end
