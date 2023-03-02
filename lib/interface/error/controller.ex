# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.Error.Controller do
  use Phoenix.Controller

  def call(conn, {:error, status}) when is_atom(status) do
    code = Plug.Conn.Status.code(status)

    conn
    |> put_status(code)
    |> put_view(html: Demo.Interface.Error.HTML)
    |> render("#{code}.html")
  end
end
