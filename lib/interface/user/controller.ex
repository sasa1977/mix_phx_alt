# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Controller do
  use Demo.Interface.Controller

  alias Demo.Core.{Model, User}

  def registration_form(conn, _params),
    do: render(conn, :registration_form, changeset: Ecto.Changeset.change(%Model.User{}))

  def register(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case User.register(email, password) do
      {:ok, _token} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: "/")

      {:error, changeset} ->
        render(conn, :registration_form, changeset: changeset)
    end
  end
end
