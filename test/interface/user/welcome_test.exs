defmodule Demo.Interface.User.WelcomeTest do
  use Demo.Test.ConnCase, async: true

  import Demo.Test.Client

  describe "welcome page" do
    test "redirects to login if the user is anonymous" do
      conn = get(build_conn(), "/")
      assert redirected_to(conn) == ~p"/login"
    end

    test "redirects to registration if the token expired" do
      conn = register!()
      expire_last_token()

      conn = conn |> recycle() |> get("/")
      assert redirected_to(conn) == ~p"/login"
    end

    test "greets the authenticated user" do
      conn = register!() |> recycle() |> get("/")
      response = html_response(conn, 200)
      assert response =~ "Welcome"
      assert response =~ "Log out"
    end
  end
end
