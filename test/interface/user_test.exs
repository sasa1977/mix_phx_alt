defmodule Demo.Interface.UserTest do
  use Demo.Test.ConnCase, async: true

  describe "welcome page" do
    test "is the default page" do
      assert Routes.user_path(build_conn(), :welcome) == "/"
    end

    test "redirects to registration if the user is anonymous" do
      conn = get(build_conn(), "/")
      assert redirected_to(conn) == Routes.user_path(conn, :registration_form)
    end

    test "redirects to registration if the token expired" do
      conn = register!(valid_registration_params())

      sixty_days_ago =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.truncate(:second)
        |> NaiveDateTime.add(-60 * 24 * 60 * 60)

      Demo.Core.Repo.get_by!(Demo.Core.Model.Token, user_id: conn.assigns.current_user.id)
      |> Ecto.Changeset.change(inserted_at: sixty_days_ago)
      |> Demo.Core.Repo.update!()

      conn = conn |> recycle() |> get("/")
      assert redirected_to(conn) == Routes.user_path(conn, :registration_form)
    end

    test "greets the authenticated user" do
      conn = register!(valid_registration_params()) |> recycle() |> get("/")
      assert html_response(conn, 200) =~ "Welcome"
    end
  end

  describe "registration form" do
    test "is rendered for a guest" do
      conn = get(build_conn(), "/registration_form")
      response = html_response(conn, 200)
      assert response =~ ~s/<input id="user_email" name="user[email]/
      assert response =~ ~s/<input id="user_password" name="user[password]/
    end

    test "redirects if the user is authenticated" do
      conn = register!(valid_registration_params()) |> recycle() |> get("/registration_form")
      assert redirected_to(conn) == Routes.user_path(conn, :welcome)
    end
  end

  describe "registration" do
    test "succeeds with valid parameters" do
      params = valid_registration_params()
      assert {:ok, conn} = register(params)

      assert conn.resp_body =~ "User created successfully."
      assert Demo.Interface.Auth.current_user(conn).email == params.email
      assert conn.request_path == Routes.user_path(conn, :welcome)
    end

    test "rejects invalid password" do
      assert {:error, conn} = register(password: nil)
      assert "can't be blank" in errors(conn, :password)

      assert {:error, conn} = register(password: "")
      assert "can't be blank" in errors(conn, :password)

      assert {:error, conn} = register(password: "12345678901")
      assert "should be at least 12 characters" in errors(conn, :password)

      assert {:error, conn} = register(password: String.duplicate("1", 73))
      assert "should be at most 72 characters" in errors(conn, :password)
    end

    test "rejects invalid email" do
      assert {:error, conn} = register(email: nil)
      assert "can't be blank" in errors(conn, :email)

      assert {:error, conn} = register(email: "")
      assert "can't be blank" in errors(conn, :email)

      assert {:error, conn} = register(email: "foo bar")
      assert "must have the @ sign and no spaces" in errors(conn, :email)

      assert {:error, conn} = register(email: "foo@ba r")
      assert "must have the @ sign and no spaces" in errors(conn, :email)

      assert {:error, conn} = register(email: "foo@bar.baz" <> String.duplicate("1", 160))
      assert "should be at most 160 character(s)" in errors(conn, :email)
    end

    test "rejects duplicate mail" do
      registration_params = valid_registration_params()
      register!(registration_params)

      assert {:error, conn} = register(registration_params)
      assert "has already been taken" in errors(conn, :email)
    end
  end

  defp errors(conn, field), do: changeset_errors(conn.assigns.changeset, field)

  defp register!(params) do
    {:ok, user} = register(params)
    user
  end

  defp register(params) do
    params = Map.merge(valid_registration_params(), Map.new(params))
    conn = post(build_conn(), "/register", %{user: Map.new(params)})

    with :ok <- validate(conn.status == 302, conn) do
      conn = conn |> recycle() |> get(redirected_to(conn))
      assert conn.status == 200
      {:ok, conn}
    end
  end

  defp valid_registration_params,
    do: %{email: "#{unique("username")}@foo.bar", password: "123456789012"}
end
