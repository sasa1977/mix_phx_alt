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
