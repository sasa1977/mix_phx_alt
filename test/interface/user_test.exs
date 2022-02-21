defmodule Demo.Interface.UserTest do
  use Demo.Test.ConnCase, async: true

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

  describe "start registration" do
    test "form is rendered for a guest" do
      conn = get(build_conn(), "/start_registration")
      response = html_response(conn, 200)
      assert response =~ ~s/<input id="user_email" name="user[email]/
      refute response =~ "Log out"
    end

    test "form redirects if the user is authenticated" do
      conn = register!() |> recycle() |> get("/start_registration")
      assert redirected_to(conn) == Routes.user_path(conn, :welcome)
    end

    test "rejects invalid email" do
      assert {:error, conn} = start_registration(nil)
      assert "can't be blank" in errors(conn, :email)

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
      token = start_registration!(new_email())
      conn = get(build_conn(), "/finish_registration/#{token}")
      response = html_response(conn, 200)
      assert response =~ ~s/<input id="user_password" name="user[password]/
      refute response =~ "Log out"
    end

    test "form returns 404 if the token is invalid" do
      conn = get(build_conn(), "/finish_registration/invalid_token")
      assert conn.status == 404
    end

    test "form redirects if the user is authenticated" do
      conn = register!() |> recycle() |> get("/finish_registration/some_token")
      assert redirected_to(conn) == Routes.user_path(conn, :welcome)
    end

    test "succeeds with valid data" do
      token = start_registration!(new_email())
      assert {:ok, conn} = finish_registration(token, new_password())
      assert conn.request_path == Routes.user_path(conn, :welcome)
    end

    test "rejects invalid password" do
      token = start_registration!(new_email())

      assert {:error, conn} = finish_registration(token, nil)
      assert "can't be blank" in errors(conn, :password)

      assert {:error, conn} = finish_registration(token, "")
      assert "can't be blank" in errors(conn, :password)

      assert {:error, conn} = finish_registration(token, "12345678901")
      assert "should be at least 12 characters" in errors(conn, :password)

      assert {:error, conn} = finish_registration(token, String.duplicate("1", 73))
      assert "should be at most 72 characters" in errors(conn, :password)
    end

    test "fails for invalid token" do
      assert {:error, conn} = finish_registration("invalid_token", new_password())
      assert html_response(conn, 404)
    end

    test "fails if the user is already activated" do
      email = new_email()

      token1 = start_registration!(email)
      token2 = start_registration!(email)

      finish_registration!(token1, new_password())

      assert {:error, conn} = finish_registration(token2, new_password())
      assert html_response(conn, 404)
    end

    test "token can only be used once" do
      params = valid_registration_params()

      token = start_registration!(params.email)
      finish_registration!(token, params.password)

      assert {:error, conn} = finish_registration(token, params.password)
      assert html_response(conn, 404)
    end
  end

  describe "login" do
    test "succeeds with valid parameters" do
      params = valid_registration_params()
      register!(params)

      assert {:ok, conn} = login(params)
      assert conn.request_path == Routes.user_path(conn, :welcome)

      # verify that the user is not remembered
      conn = conn |> recycle() |> delete_req_cookie("_demo_key") |> get("/")
      assert assert redirected_to(conn) == Routes.user_path(conn, :login)
    end

    test "remembers the user" do
      params = valid_registration_params()
      register!(params)

      conn =
        login!(Map.merge(params, %{remember: "true"}))
        |> recycle()
        |> delete_req_cookie("_demo_key")
        |> get("/")

      assert html_response(conn, 200) =~ "Log out"
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

  defp logged_in?(conn) do
    conn = conn |> recycle() |> get(Routes.user_path(conn, :welcome))
    conn.status == 200 and conn.assigns.current_user != nil
  end

  defp errors(conn, field), do: changeset_errors(conn.assigns.changeset, field)

  defp register!(params \\ %{}) do
    params = Map.merge(valid_registration_params(), Map.new(params))

    start_registration!(params.email)
    |> finish_registration!(params.password)
  end

  defp start_registration!(email) do
    {:ok, token} = start_registration(email)
    false = is_nil(token)
    token
  end

  defp start_registration(email) do
    conn = post(build_conn(), "/start_registration", %{user: %{email: email}})
    assert conn.status == 200

    if conn.resp_body =~ "The email with further instructions has been sent to #{email}",
      do: {:ok, confirm_email_token(email)},
      else: {:error, conn}
  end

  defp confirm_email_token(email) do
    receive do
      {:email, %{to: [{nil, ^email}], subject: "Registration"} = registration_email} ->
        ~r[http://.*/finish_registration/(?<token>.*)]
        |> Regex.named_captures(registration_email.text_body)
        |> Map.fetch!("token")
    after
      0 -> nil
    end
  end

  defp finish_registration!(token, password) do
    {:ok, conn} = finish_registration(token, password)
    conn
  end

  defp finish_registration(token, password) do
    conn = post(build_conn(), "/finish_registration/#{token}", %{user: %{password: password}})

    with :ok <- validate(conn.status == 302, conn) do
      conn = conn |> recycle() |> get(redirected_to(conn))
      assert conn.status == 200
      {:ok, conn}
    end
  end

  defp valid_registration_params, do: %{email: new_email(), password: new_password()}

  defp new_email, do: "#{unique("username")}@foo.bar"
  defp new_password, do: unique("12345678901")

  defp login!(params) do
    {:ok, conn} = login(params)
    conn
  end

  defp login(params) do
    params = Map.merge(%{remember: "false"}, Map.new(params))
    conn = post(build_conn(), "/login", %{user: params})

    if params.remember == "true" do
      assert %{"auth_token" => %{max_age: max_age, same_site: "Lax"}} = conn.resp_cookies
      assert max_age == Model.Token.validity(:auth) * 24 * 60 * 60
    end

    with :ok <- validate(conn.status == 302, conn) do
      conn = conn |> recycle() |> get(redirected_to(conn))
      assert conn.status == 200
      {:ok, conn}
    end
  end

  defp start_password_reset!(email) do
    {:ok, token} = start_password_reset(email)
    false = is_nil(token)
    token
  end

  defp start_password_reset(email) do
    conn = post(build_conn(), "/start_password_reset", %{user: %{email: email}})
    assert conn.status == 200

    if conn.resp_body =~ "The email with further instructions has been sent to #{email}",
      do: {:ok, password_reset_token(email)},
      else: {:error, conn}
  end

  defp password_reset_token(email) do
    receive do
      {:email, %{to: [{nil, ^email}], subject: "Password reset"} = mail} ->
        ~r[http://.*/reset_password/(?<token>.*)]
        |> Regex.named_captures(mail.text_body)
        |> Map.fetch!("token")
    after
      0 -> nil
    end
  end

  defp reset_password!(token, password) do
    {:ok, conn} = reset_password(token, password)
    conn
  end

  defp reset_password(token, password) do
    conn = post(build_conn(), "/reset_password/#{token}", user: %{password: password})

    with :ok <- validate(conn.status == 302, conn) do
      conn = conn |> recycle() |> get(redirected_to(conn))
      assert conn.status == 200
      {:ok, conn}
    end
  end

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
