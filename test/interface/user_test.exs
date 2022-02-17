defmodule Demo.Interface.User do
  use Demo.Test.ConnCase, async: true

  describe "registration" do
    test "succeeds with valid parameters" do
      params = valid_registration_params()
      assert {:ok, conn} = register(params)

      assert conn.resp_body =~ "User created successfully."
      assert conn.assigns.current_user.email == params.email
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
