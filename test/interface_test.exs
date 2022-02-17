defmodule Demo.InterfaceTest do
  use Demo.Test.ConnCase, async: true

  test "root page redirects to registration" do
    conn = get(build_conn(), "/")
    assert redirected_to(conn) == Routes.user_path(conn, :registration_form)
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
