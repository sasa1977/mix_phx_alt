# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Controller do
  use Demo.Interface.Controller

  alias Demo.Interface.Auth
  alias Demo.Core.{Model, User}

  def registration_form(conn, _params),
    do: render(conn, :registration_form, changeset: Ecto.Changeset.change(%Model.User{}))

  def welcome(conn, _params), do: render(conn, :welcome, user: Auth.current_user(conn))

  def register(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case User.register(email, password) do
      {:ok, token} ->
        conn
        |> Auth.set_token(token)
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: Routes.user_path(conn, :welcome))

      {:error, changeset} ->
        render(conn, :registration_form, changeset: changeset)
    end
  end
end
