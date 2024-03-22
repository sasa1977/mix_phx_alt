defmodule Demo.InterfaceTest do
  use Demo.Test.ConnCase, async: true

  test "not found" do
    conn = get(build_conn(), "/users/not-found")
    assert conn.status == 404
    assert conn.resp_body == "Not Found"
  end
end
