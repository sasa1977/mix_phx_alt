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

  defp errors(conn, changeset_name, field),
    do: changeset_errors(conn.assigns[changeset_name], field)
end
