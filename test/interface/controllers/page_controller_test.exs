defmodule Demo.Interface.PageControllerTest do
  use Demo.Interface.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome!"
  end
end
