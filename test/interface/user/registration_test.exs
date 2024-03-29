defmodule Demo.Interface.User.RegistrationTest do
  use Demo.Test.ConnCase, async: true

  import Demo.Test.Client

  describe "start registration" do
    test "form is rendered for a guest" do
      conn = get(build_conn(), "/start_registration_form")
      response = html_response(conn, 200)
      assert response =~ ~s/id="form_email"/
      refute response =~ "Log out"
    end

    test "form redirects if the user is authenticated" do
      conn = register!() |> recycle() |> get("/start_registration_form")
      assert redirected_to(conn) == ~p"/"
    end

    test "rejects invalid email" do
      assert {:error, conn} = start_registration("")
      assert "can't be blank" in errors(conn, :email)

      assert {:error, conn} = start_registration("foo bar")
      assert "must have the @ sign and no spaces" in errors(conn, :email)

      assert {:error, conn} = start_registration("foo@ba r")
      assert "must have the @ sign and no spaces" in errors(conn, :email)

      assert {:error, conn} = start_registration("foo@bar.baz" <> String.duplicate("1", 160))
      assert "should be at most 160 character(s)" in errors(conn, :email)
    end

    test "succeds without sending an email if the email address is taken" do
      email = new_email()
      register!(email: email)

      assert {:ok, token} = start_registration(email)
      assert token == nil
    end
  end

  describe "finish registration" do
    test "form is rendered for a guest" do
      token = ok!(start_registration(new_email()))
      conn = get(build_conn(), "/finish_registration_form/#{token}")
      response = html_response(conn, 200)
      assert response =~ ~s/id="form_password"/
      refute response =~ "Log out"
    end

    test "form returns 404 if the token is invalid" do
      conn = get(build_conn(), "/finish_registration_form/invalid_token")
      assert conn.status == 404
    end

    test "form redirects if the user is authenticated" do
      conn = register!() |> recycle() |> get("/finish_registration_form/some_token")
      assert redirected_to(conn) == ~p"/"
    end

    test "succeeds with valid token" do
      token = ok!(start_registration(new_email()))
      assert {:ok, conn} = finish_registration(token, new_password())
      assert conn.request_path == ~p"/"
    end

    test "rejects invalid password" do
      token = ok!(start_registration(new_email()))

      assert {:error, conn} = finish_registration(token, nil)
      assert "can't be blank" in errors(conn, :password)

      assert {:error, conn} = finish_registration(token, "")
      assert "can't be blank" in errors(conn, :password)

      assert {:error, conn} = finish_registration(token, "12345678901")
      assert "should be at least 12 character(s)" in errors(conn, :password)

      assert {:error, conn} = finish_registration(token, String.duplicate("1", 73))
      assert "should be at most 72 character(s)" in errors(conn, :password)
    end

    test "fails for invalid token" do
      # malformed token
      assert {:error, conn} = finish_registration("invalid_token", new_password())
      assert html_response(conn, 404)

      # token of a wrong type
      token = ok!(start_registration(new_email()))
      update_last_token(type: :auth)

      assert {:error, conn} = finish_registration(token, new_password())
      assert html_response(conn, 404)

      # expired token
      token = ok!(start_registration(new_email()))
      expire_last_token()

      assert {:error, conn} = finish_registration(token, new_password())
      assert html_response(conn, 404)
    end

    test "fails if the user is already activated" do
      email = new_email()

      token1 = ok!(start_registration(email))
      token2 = ok!(start_registration(email))

      ok!(finish_registration(token1, new_password()))

      assert {:error, conn} = finish_registration(token2, new_password())
      assert html_response(conn, 404)
    end

    test "token can only be used once" do
      params = valid_registration_params()

      token = ok!(start_registration(params.email))
      ok!(finish_registration(token, params.password))

      assert {:error, conn} = finish_registration(token, params.password)
      assert html_response(conn, 404)
    end
  end

  defp errors(conn, field), do: changeset_errors(conn.assigns.changeset, field)
end
