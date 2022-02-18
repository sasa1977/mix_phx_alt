# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Controller do
  use Demo.Interface.Controller
  alias Demo.Core.{Model, User}

  def welcome(conn, _params), do: render(conn, :welcome)

  def registration_form(conn, _params),
    do: render(conn, :registration_form, changeset: Ecto.Changeset.change(%Model.User{}))

  def register(conn, %{"user" => %{"email" => email}}) do
    case User.register(email, &Routes.user_url(conn, :activation_form, &1)) do
      :ok -> render(conn, :activation_pending, email: email)
      {:error, changeset} -> render(conn, :registration_form, changeset: changeset)
    end
  end

  def activation_form(conn, %{"token" => token}) do
    conn
    |> put_session(:activation_token, token)
    |> render(:activation_form, changeset: Ecto.Changeset.change(%Model.User{}))
  end

  def activate(conn, %{"user" => %{"password" => password}}) do
    case User.activate(get_session(conn, :activation_token), password) do
      {:ok, token} ->
        conn
        |> clear_session()
        |> put_session(:user_token, token)
        |> put_flash(:info, "User activated successfully.")
        |> redirect(to: Routes.user_path(conn, :welcome))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :activation_form, changeset: changeset)

      :error ->
        {:error, :not_found}
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
