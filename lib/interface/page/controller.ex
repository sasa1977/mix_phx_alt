# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.Page.Controller do
  use Demo.Interface.Controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
