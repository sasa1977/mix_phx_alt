defmodule Demo.Interface.User.SettingsTest do
  use Demo.Test.ConnCase, async: true

  import Demo.Test.Client

  describe "settings form" do
    test "is rendered if the user is authenticated" do
      conn = register!() |> recycle() |> get("/settings")
      response = html_response(conn, 200)
      assert response =~ ~s/<input id="password_new" name="password[new]/
    end

    test "redirects an anonymous user" do
      conn = get(build_conn(), "/settings")
      assert redirected_to(conn) == Routes.user_path(conn, :login)
    end
  end

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
      ok!(login(params))
      ok!(login(Map.put(params, :remember, "true")))
      ok!(start_password_reset(params.email))

      ok!(change_password(params.email, params.password, new_password()))

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

    defp change_password(conn \\ nil, email, current, new) do
      conn =
        (conn || ok!(login(email: email, password: current)))
        |> recycle()
        |> post("/change_password", password: %{current: current, new: new})

      with :ok <- validate(conn.status == 302, conn) do
        conn = conn |> recycle() |> get(redirected_to(conn))
        200 = conn.status
        {:ok, conn}
      end
    end
  end

  describe "start email change" do
    test "succeeds with valid params" do
      params = valid_registration_params()
      register!(params)
      assert {:ok, _token} = start_email_change(params, new_email())
    end

    test "allows different users to attempt a change to the same email" do
      params1 = valid_registration_params()
      register!(params1)

      params2 = valid_registration_params()
      register!(params2)

      new_email = new_email()

      assert {:ok, _token} = start_email_change(params1, new_email)
      assert {:ok, _token} = start_email_change(params2, new_email)
    end

    test "doesn't send an email if the account already exists" do
      params1 = valid_registration_params()
      register!(params1)

      params2 = valid_registration_params()
      register!(params2)

      assert {:ok, nil} = start_email_change(params1, params2.email)
    end

    test "rejects invalid email" do
      params = valid_registration_params()
      register!(params)

      assert {:error, conn} = start_email_change(params, nil)
      assert "can't be blank" in errors(conn, :email_changeset, :email)

      assert {:error, conn} = start_email_change(params, "")
      assert "can't be blank" in errors(conn, :email_changeset, :email)

      assert {:error, conn} = start_email_change(params, "foo bar")
      assert "must have the @ sign and no spaces" in errors(conn, :email_changeset, :email)

      assert {:error, conn} = start_email_change(params, "foo@ba r")
      assert "must have the @ sign and no spaces" in errors(conn, :email_changeset, :email)

      assert {:error, conn} = start_email_change(params, "a@b.c" <> String.duplicate("1", 160))
      assert "should be at most 160 character(s)" in errors(conn, :email_changeset, :email)

      assert {:error, conn} = start_email_change(params, params.email)
      assert "is the same" in errors(conn, :email_changeset, :email)
    end

    defp start_email_change(login_params, new_email) do
      conn =
        ok!(login(login_params))
        |> recycle()
        |> post("/start_email_change",
          change_email: %{email: new_email, password: login_params.password}
        )

      200 = conn.status

      if conn.resp_body =~ "The email with further instructions has been sent to #{new_email}",
        do: {:ok, confirm_email_token(new_email)},
        else: {:error, conn}
    end

    defp confirm_email_token(email) do
      receive do
        {:email, %{to: [{nil, ^email}], subject: "Confirm email change"} = registration_email} ->
          ~r[http://.*/change_email/(?<token>.*)]
          |> Regex.named_captures(registration_email.text_body)
          |> Map.fetch!("token")
      after
        0 -> nil
      end
    end
  end

  defp errors(conn, changeset_name, field),
    do: changeset_errors(conn.assigns[changeset_name], field)
end
