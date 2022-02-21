defmodule Demo.Interface.UserTest do
  use Demo.Test.ConnCase, async: true

  import Demo.Test.Client
  import Ecto.Query

  alias Demo.Core.{Model, Repo}

  describe "welcome page" do
    test "is the default page" do
      assert Routes.user_path(build_conn(), :welcome) == "/"
    end

    test "redirects to login if the user is anonymous" do
      conn = get(build_conn(), "/")
      assert redirected_to(conn) == Routes.user_path(conn, :login)
    end

    test "redirects to registration if the token expired" do
      conn = register!()
      expire_last_token()

      conn = conn |> recycle() |> get("/")
      assert redirected_to(conn) == Routes.user_path(conn, :login)
    end

    test "greets the authenticated user" do
      conn = register!() |> recycle() |> get("/")
      response = html_response(conn, 200)
      assert response =~ "Welcome"
      assert response =~ "Log out"
    end
  end

  describe "start password reset" do
    test "form is rendered for a guest" do
      conn = get(build_conn(), "/start_password_reset")
      response = html_response(conn, 200)
      assert response =~ ~s/<input id="user_email" name="user[email]/
      refute response =~ "Log out"
    end

    test "form redirects if the user is authenticated" do
      conn = register!() |> recycle() |> get("/start_password_reset")
      assert redirected_to(conn) == Routes.user_path(conn, :welcome)
    end

    test "creates the token if the user exists" do
      email = new_email()
      register!(email: email)

      assert {:ok, token} = start_password_reset(email)
      assert token != nil
    end

    test "doesn't create the token if the user doesn't exist" do
      assert {:ok, token} = start_password_reset("unknown_user@foo.bar")
      assert token == nil
    end

    test "rejects invalid email" do
      assert {:error, conn} = start_password_reset(nil)
      assert "can't be blank" in errors(conn, :email)

      assert {:error, conn} = start_password_reset("")
      assert "can't be blank" in errors(conn, :email)

      assert {:error, conn} = start_password_reset("foo bar")
      assert "must have the @ sign and no spaces" in errors(conn, :email)

      assert {:error, conn} = start_password_reset("foo@ba r")
      assert "must have the @ sign and no spaces" in errors(conn, :email)

      assert {:error, conn} = start_password_reset("foo@bar.baz" <> String.duplicate("1", 160))
      assert "should be at most 160 character(s)" in errors(conn, :email)
    end
  end

  describe "reset password" do
    test "form is rendered for a guest" do
      email = new_email()
      register!(email: email)
      token = start_password_reset!(email)

      conn = get(build_conn(), "/reset_password/#{token}")
      response = html_response(conn, 200)
      assert response =~ ~s/<input id="user_password" name="user[password]/
      refute response =~ "Log out"
    end

    test "form returns 404 if the token is invalid" do
      conn = get(build_conn(), "/reset_password/invalid_token")
      assert conn.status == 404
    end

    test "form redirects if the user is authenticated" do
      conn = register!() |> recycle() |> get("/reset_password/some_token")
      assert redirected_to(conn) == Routes.user_path(conn, :welcome)
    end

    test "succeeds with a valid token" do
      registration_params = valid_registration_params()
      register!(registration_params)
      token = start_password_reset!(registration_params.email)

      new_password = new_password()
      assert {:ok, conn} = reset_password(token, new_password)
      assert conn.request_path == Routes.user_path(conn, :welcome)

      assert {:error, _} = login(registration_params)
      assert {:ok, _} = login(%{registration_params | password: new_password})
    end

    test "fails for invalid token" do
      assert {:error, conn} = reset_password("invalid_token", new_password())
      assert html_response(conn, 404)
    end

    test "token can only be used once" do
      email = new_email()
      register!(email: email)
      token = start_password_reset!(email)

      reset_password!(token, new_password())

      assert {:error, conn} = reset_password(token, new_password())
      assert html_response(conn, 404)
    end

    test "rejects invalid password" do
      email = new_email()
      register!(email: email)
      token = start_password_reset!(email)

      assert {:error, conn} = reset_password(token, nil)
      assert "can't be blank" in errors(conn, :password)

      assert {:error, conn} = reset_password(token, "")
      assert "can't be blank" in errors(conn, :password)

      assert {:error, conn} = reset_password(token, "12345678901")
      assert "should be at least 12 characters" in errors(conn, :password)

      assert {:error, conn} = reset_password(token, String.duplicate("1", 73))
      assert "should be at most 72 characters" in errors(conn, :password)
    end
  end

  test "logout clears the current user" do
    registration_params = valid_registration_params()
    register!(registration_params)

    logged_in_conn = login!(Map.put(registration_params, :remember, "true"))
    logged_out_conn = logged_in_conn |> recycle() |> delete("/logout")

    assert redirected_to(logged_out_conn) == Routes.user_path(logged_out_conn, :login_form)

    assert get_session(logged_out_conn) == %{}
    assert is_nil(logged_out_conn.assigns.current_user)
    assert logged_out_conn.resp_cookies["auth_token"].max_age == 0

    refute logged_in?(logged_in_conn)
  end

  test "periodic token cleanup deletes expired tokens" do
    start_registration!(new_email())
    expire_last_token(_days = 7)

    register!()
    expire_last_token(_days = 60)

    conn1 = register!()
    token1 = start_registration!(new_email())

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), Demo.Core.User.TokenCleanup)
    {:ok, :normal} = Periodic.Test.sync_tick(Demo.Core.User.TokenCleanup)

    assert Repo.aggregate(Model.Token, :count) == 2

    # this proves that survived tokens are still working
    assert logged_in?(conn1)
    assert {:ok, _} = finish_registration(token1, valid_registration_params().password)
  end

  defp errors(conn, field), do: changeset_errors(conn.assigns.changeset, field)

  defp expire_last_token(days \\ 60) do
    last_token = Repo.one!(from Model.Token, limit: 1, order_by: [desc: :inserted_at])

    {1, _} =
      Repo.update_all(
        from(Model.Token,
          where: [id: ^last_token.id],
          update: [set: [inserted_at: ago(^days, "day")]]
        ),
        []
      )

    :ok
  end
end
