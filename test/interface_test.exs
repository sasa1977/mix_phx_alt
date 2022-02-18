defmodule Demo.InterfaceTest do
  use Demo.Test.ConnCase, async: true

  test "not found" do
    {_status, _headers, response} =
      assert_error_sent 404, fn -> get(build_conn(), "/users/not-found") end

    assert response == "Not Found"
  end

  test "server error" do
    # sending broken data to activate to trigger an exception
    {_status, _headers, response} =
      assert_error_sent 500, fn ->
        post(build_conn(), "/activate", %{user: %{password: 2}})
      end

    assert response == "Internal Server Error"
  end
end
