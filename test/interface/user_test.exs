defmodule Demo.Interface.UserTest do
  use Demo.Test.ConnCase, async: true

  import Ecto.Query

  alias Demo.Core.{Model, Repo}

  describe "welcome page" do
    test "is the default page" do
      assert Routes.user_path(build_conn(), :welcome) == "/"
    end

    test "redirects to registration if the user is anonymous" do
      conn = get(build_conn(), "/")
      assert redirected_to(conn) == Routes.user_path(conn, :registration_form)
    end

    test "redirects to registration if the token expired" do
      conn = register_and_activate!()
      expire_last_token()

      conn = conn |> recycle() |> get("/")
      assert redirected_to(conn) == Routes.user_path(conn, :registration_form)
    end

    test "greets the authenticated user" do
      conn = register_and_activate!() |> recycle() |> get("/")
      response = html_response(conn, 200)
      assert response =~ "Welcome"
      assert response =~ "Log out"
    end
  end

  describe "registration" do
    test "form is rendered for a guest" do
      conn = get(build_conn(), "/registration_form")
      response = html_response(conn, 200)
      assert response =~ ~s/<input id="user_email" name="user[email]/
      refute response =~ "Log out"
    end

    test "form redirects if the user is authenticated" do
      conn =
        register_and_activate!()
        |> recycle()
        |> get("/registration_form")

      assert redirected_to(conn) == Routes.user_path(conn, :welcome)
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

    test "succeds without sending an email if the email address is taken" do
      params = valid_registration_params()
      register_and_activate!(params)
      assert register!(params) == nil
    end
  end

  describe "activation" do
    test "form is rendered for a guest" do
      conn = get(build_conn(), "/activation_form/some_token")
      response = html_response(conn, 200)
      assert response =~ ~s/<input id="user_password" name="user[password]/
      refute response =~ "Log out"
    end

    test "form redirects if the user is authenticated" do
      conn =
        register_and_activate!()
        |> recycle()
        |> get("/activation_form/some_token")

      assert redirected_to(conn) == Routes.user_path(conn, :welcome)
    end

    test "rejects invalid password" do
      activation_path = register!()

      assert {:error, conn} = activate(%{password: nil}, activation_path)
      assert "can't be blank" in errors(conn, :password)

      assert {:error, conn} = activate(%{password: ""}, activation_path)
      assert "can't be blank" in errors(conn, :password)

      assert {:error, conn} = activate(%{password: "12345678901"}, activation_path)
      assert "should be at least 12 characters" in errors(conn, :password)

      assert {:error, conn} = activate(%{password: String.duplicate("1", 73)}, activation_path)
      assert "should be at most 72 characters" in errors(conn, :password)
    end

    test "fails for invalid token" do
      assert {:error, conn} =
               activate(valid_registration_params(), "/activation_form/invalid_token")

      assert html_response(conn, 404)
    end

    test "fails if the user is already activated" do
      params = valid_registration_params()

      activation_path1 = register!(params)
      activation_path2 = register!(params)

      activate!(params, activation_path1)

      assert {:error, conn} = activate(valid_registration_params(), activation_path2)
      assert html_response(conn, 404)
    end
  end

  test "logout clears the current user" do
    logged_in_conn = register_and_activate!()

    logged_out_conn = logged_in_conn |> recycle() |> delete("/logout")

    assert redirected_to(logged_out_conn) == Routes.user_path(logged_out_conn, :registration_form)
    assert Plug.Conn.get_session(logged_out_conn) == %{}
    assert is_nil(logged_out_conn.assigns.current_user)

    refute still_logged_in?(logged_in_conn)
  end

  test "periodic token cleanup deletes expired tokens" do
    register!()
    expire_last_token(_days = 7)

    register_and_activate!()
    expire_last_token(_days = 60)

    conn1 = register_and_activate!()
    activation_path = register!()

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), Demo.Core.TokenCleanup)
    {:ok, :normal} = Periodic.Test.sync_tick(Demo.Core.TokenCleanup)

    assert Repo.aggregate(Model.Token, :count) == 2
    assert still_logged_in?(conn1)
    assert {:ok, _} = activate(valid_registration_params(), activation_path)
  end

  defp still_logged_in?(conn) do
    conn = conn |> recycle() |> get(Routes.user_path(conn, :welcome))
    conn.status == 200 and conn.assigns.current_user != nil
  end

  defp errors(conn, field), do: changeset_errors(conn.assigns.changeset, field)

  defp register_and_activate!(params \\ %{}) do
    params = Map.merge(valid_registration_params(), Map.new(params))
    activate!(params, register!(params))
  end

  defp register!(params \\ %{}) do
    {:ok, activation_path} = register(params)
    activation_path
  end

  defp register(params) do
    params = Map.merge(valid_registration_params(), Map.new(params))
    conn = post(build_conn(), "/register", %{user: Map.take(params, [:email])})
    assert conn.status == 200

    if conn.resp_body =~ "Activation email has been sent",
      do: {:ok, activation_path(params.email)},
      else: {:error, conn}
  end

  defp activate!(params, activation_path) do
    {:ok, conn} = activate(params, activation_path)
    conn
  end

  defp activate(params, activation_path) do
    # render finalize form to set the token into session
    conn = build_conn() |> get(activation_path)

    # activate with the given password
    params = Map.take(params, [:password])
    conn = conn |> recycle() |> post(Routes.user_path(conn, :activate), %{user: params})

    with :ok <- validate(conn.status == 302, conn) do
      conn = conn |> recycle() |> get(redirected_to(conn))
      assert conn.status == 200
      {:ok, conn}
    end
  end

  defp activation_path(email) do
    receive do
      {:email, %{to: [{nil, ^email}], subject: "Activate your account"} = activation_email} ->
        ~r[http://.*(?<activation_path>/activation_form/.*)]
        |> Regex.named_captures(activation_email.text_body)
        |> Map.fetch!("activation_path")
    after
      0 -> nil
    end
  end

  defp valid_registration_params,
    do: %{email: "#{unique("username")}@foo.bar", password: "123456789012"}

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
