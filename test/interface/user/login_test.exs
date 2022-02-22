defmodule Demo.Interface.User.LoginTest do
  use Demo.Test.ConnCase, async: true

  import Demo.Test.Client
  import Ecto.Query

  describe "login" do
    test "succeeds with valid parameters" do
      params = valid_registration_params()
      register!(params)

      assert {:ok, conn} = login(params)
      assert conn.request_path == Routes.user_path(conn, :welcome)

      # verify that the user is not remembered
      conn = conn |> recycle() |> delete_req_cookie("_demo_key") |> get("/")
      assert redirected_to(conn) == Routes.user_path(conn, :login)
    end

    test "remembers the user" do
      params = valid_registration_params()
      register!(params)

      conn =
        login(Map.merge(params, %{remember: "true"}))
        |> ok!()
        |> recycle_no_session()
        |> get("/")

      assert html_response(conn, 200) =~ "Log out"
    end

    test "fails with invalid remember cookie" do
      params = valid_registration_params()
      register!(params)

      conn = ok!(login(Map.merge(params, %{remember: "true"})))
      update_last_token(hash: fragment("digest(gen_random_uuid()::text, 'sha256')::bytea"))

      conn = conn |> recycle_no_session() |> get("/")
      assert redirected_to(conn) == Routes.user_path(conn, :login)
    end

    test "fails with wrong token type" do
      params = valid_registration_params()
      register!(params)

      conn = ok!(login(Map.merge(params, %{remember: "true"})))
      update_last_token(type: :password_reset)

      conn = conn |> recycle_no_session() |> get("/")
      assert redirected_to(conn) == Routes.user_path(conn, :login)
    end

    test "fails with expired token" do
      params = valid_registration_params()
      register!(params)

      conn = ok!(login(Map.merge(params, %{remember: "true"})))
      expire_last_token()

      conn = conn |> recycle() |> delete_req_cookie("_demo_key") |> get("/")
      assert redirected_to(conn) == Routes.user_path(conn, :login)
    end

    test "fails with invalid password" do
      params = valid_registration_params()
      register!(%{params | password: "invalid password"})

      assert {:error, conn} = login(params)
      assert conn.resp_body =~ "Invalid email or password"
    end

    test "fails with invalid email" do
      params = valid_registration_params()
      register!(%{params | email: "invalid@email.com"})

      assert {:error, conn} = login(params)
      assert conn.resp_body =~ "Invalid email or password"
    end
  end

  defp recycle_no_session(conn), do: conn |> recycle() |> delete_req_cookie("_demo_key")
end
