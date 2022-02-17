defmodule Demo.InterfaceTest do
  use Demo.Test.ConnCase, async: true

  test "not found", %{conn: conn} do
    {_status, _headers, response} = assert_error_sent 404, fn -> get(conn, "/users/not-found") end
    assert response == "Not Found"
  end

  test "server error", %{conn: conn} do
    # sending broken data to register to trigger an exception
    {_status, _headers, response} =
      assert_error_sent 500, fn -> post(conn, "/register", %{user: %{email: 1, password: 2}}) end

    assert response == "Internal Server Error"
  end
end
