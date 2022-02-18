# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.Error.Controller do
  use Phoenix.Controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(Demo.Interface.Error.View)
    |> render(:"404")
  end
end
