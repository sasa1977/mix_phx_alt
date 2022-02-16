defmodule Demo.Interface.User do
  use Demo.Test.ConnCase, async: true

  describe "registration" do
    test "succeeds with valid parameters" do
      assert register(valid_registration_params()) == :ok
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

  defp register!(params), do: :ok = register(params)

  defp register(params) do
    params = Map.merge(valid_registration_params(), Map.new(params))
    conn = post(build_conn(), "/register", %{user: Map.new(params)})

    with :ok <- validate(conn.status == 302, conn),
         redirected_to = redirected_to(conn),
         :ok <- validate(redirected_to == "/", conn),
         conn = conn |> recycle() |> get(redirected_to),
         :ok <- validate(conn.status == 200, conn) do
      response_content_type(conn, :html)
      validate(conn.resp_body =~ "User created successfully.", conn)
    end
  end

  defp valid_registration_params,
    do: %{email: "#{unique("username")}@foo.bar", password: "123456789012"}
end
