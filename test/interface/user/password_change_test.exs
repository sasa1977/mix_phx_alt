defmodule Demo.Interface.User.PasswordResetTest do
  use Demo.Test.ConnCase, async: true

  import Demo.Test.Client

  describe "change password" do
    test "succeeds with valid parameters" do
      params = valid_registration_params()
      previous_conn = register!(params)

      new_password = new_password()
      assert {:ok, conn} = change_password(params.email, params.password, new_password)

      assert conn.resp_body =~ "Password changed successfully."
      assert logged_in?(conn)
      refute logged_in?(previous_conn)

      assert {:ok, _} = login(%{params | password: new_password})
      assert {:error, _} = login(params)
    end

    test "deletes all other tokens" do
      params = valid_registration_params()
      register!(params)

      # create other tokens
      login!(params)
      login!(Map.put(params, :remember, "true"))
      start_password_reset!(params.email)

      change_password!(params.email, params.password, new_password())

      # there should be just one token (created during the password change)
      assert Demo.Core.Repo.aggregate(Demo.Core.Model.Token, :count) == 1
    end

    test "fails if old password is incorrect" do
      params = valid_registration_params()
      conn = register!(params)

      %{email: email, password: password} = params

      assert {:error, conn} = change_password(conn, email, "_#{password}", new_password())
      assert "is not valid" in errors(conn, :password_changeset, :current)
    end

    test "rejects invalid new password" do
      params = valid_registration_params()
      register!(params)

      %{email: email, password: password} = params

      assert {:error, conn} = change_password(email, password, nil)
      assert "can't be blank" in errors(conn, :password_changeset, :new)

      assert {:error, conn} = change_password(email, password, "")
      assert "can't be blank" in errors(conn, :password_changeset, :new)

      assert {:error, conn} = change_password(email, password, "12345678901")
      assert "should be at least 12 characters" in errors(conn, :password_changeset, :new)

      assert {:error, conn} = change_password(email, password, String.duplicate("1", 73))
      assert "should be at most 72 characters" in errors(conn, :password_changeset, :new)
    end

    defp change_password!(email, current, new) do
      {:ok, conn} = change_password(email, current, new)
      conn
    end

    defp change_password(conn \\ nil, email, current, new) do
      conn =
        (conn || login!(email: email, password: current))
        |> recycle()
        |> post("/change_password", password: %{current: current, new: new})

      with :ok <- validate(conn.status == 302, conn) do
        conn = conn |> recycle() |> get(redirected_to(conn))
        200 = conn.status
        {:ok, conn}
      end
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
      # malformed token
      assert {:error, conn} = reset_password("invalid_token", new_password())
      assert html_response(conn, 404)

      # confirm email token
      email = new_email()
      confirm_email_token = start_registration!(email)
      finish_registration!(confirm_email_token, new_password())

      assert {:error, conn} = reset_password(confirm_email_token, new_password())
      assert html_response(conn, 404)

      # auth_token
      registration_params = valid_registration_params()
      register!(registration_params)
      auth_token = login!(registration_params) |> Plug.Conn.get_session(:auth_token)

      assert {:error, conn} = reset_password(auth_token, new_password())
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

  defp errors(conn, changeset_name \\ :changeset, field),
    do: changeset_errors(conn.assigns[changeset_name], field)
end
