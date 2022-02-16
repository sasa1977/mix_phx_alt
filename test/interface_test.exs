defmodule Demo.InterfaceTest do
  use Demo.Test.ConnCase, async: true

  test "root page", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome!"
  end

  test "not found", %{conn: conn} do
    {_status, _headers, response} = assert_error_sent 404, fn -> get(conn, "/users/not-found") end
    assert response == "Not Found"
  end

  test "server error", %{conn: conn} do
    {_status, _headers, response} = assert_error_sent 500, fn -> get(conn, "/server_error") end
    assert response == "Internal Server Error"
  end
end
