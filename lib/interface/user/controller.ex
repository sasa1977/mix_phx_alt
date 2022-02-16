# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Controller do
  use Demo.Interface.Controller
  alias Demo.Core.User

  def register(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case User.register(email, password) do
      {:ok, _user} -> conn |> put_status(200) |> text("OK")
      {:error, changeset} -> conn |> Plug.Conn.assign(:changeset, changeset) |> put_status(400)
    end
  end
end
