defmodule Demo.Interface.User.AuthenticationTest do
  use Demo.Test.ConnCase, async: true

  import Demo.Test.Client

  alias Demo.Core.{Model, Repo}

  describe "login" do
    test "form is rendered for a guest" do
      conn = get(build_conn(), "/login_form")
      response = html_response(conn, 200)
      assert response =~ ~s/id="form_email"/
      assert response =~ ~s/id="form_password"/
    end

    test "form redirects if the user is authenticated" do
      conn = register!() |> recycle() |> get("/login_form")
      assert redirected_to(conn) == ~p"/"
    end

    test "succeeds with valid input" do
      params = valid_registration_params()
      register!(params)

      assert {:ok, conn} = login(params)
      assert conn.request_path == ~p"/"

      # verify that the user is not remembered
      conn = conn |> recycle() |> delete_req_cookie("_demo_key") |> get("/")
      assert redirected_to(conn) == ~p"/login_form"
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
      assert redirected_to(conn) == ~p"/login_form"
    end

    test "fails with wrong token type" do
      params = valid_registration_params()
      register!(params)

      conn = ok!(login(Map.merge(params, %{remember: "true"})))
      update_last_token(type: :password_reset)

      conn = conn |> recycle_no_session() |> get("/")
      assert redirected_to(conn) == ~p"/login_form"
    end

    test "fails with expired token" do
      params = valid_registration_params()
      register!(params)

      conn = ok!(login(Map.merge(params, %{remember: "true"})))
      expire_last_token()

      conn = conn |> recycle() |> delete_req_cookie("_demo_key") |> get("/")
      assert redirected_to(conn) == ~p"/login_form"
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

  test "logout clears the current user" do
    registration_params = valid_registration_params()
    register!(registration_params)

    logged_in_conn = ok!(login(Map.put(registration_params, :remember, "true")))
    logged_out_conn = logged_in_conn |> recycle() |> post("/logout")

    assert redirected_to(logged_out_conn) == ~p"/login_form"

    assert get_session(logged_out_conn) == %{}
    assert is_nil(logged_out_conn.assigns.current_user)
    assert logged_out_conn.resp_cookies["auth_token"].max_age == 0

    refute logged_in?(logged_in_conn)
  end

  test "periodic token cleanup deletes expired tokens" do
    ok!(start_registration(new_email()))
    expire_last_token()

    register!()
    expire_last_token()

    conn1 = register!()
    token1 = ok!(start_registration(new_email()))

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), Demo.Core.Token.Cleanup)
    {:ok, :normal} = Periodic.Test.sync_tick(Demo.Core.Token.Cleanup)

    assert Repo.aggregate(Model.Token, :count) == 2

    # this proves that survived tokens are still working
    assert logged_in?(conn1)
    assert {:ok, _} = finish_registration(token1, valid_registration_params().password)
  end

  defp recycle_no_session(conn), do: conn |> recycle() |> delete_req_cookie("_demo_key")
end
