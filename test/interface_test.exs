defmodule Demo.InterfaceTest do
  use Demo.Test.ConnCase, async: true

  test "not found" do
    {_status, _headers, response} =
      assert_error_sent 404, fn -> get(build_conn(), "/users/not-found") end

    assert response == "Not Found"
  end
end
