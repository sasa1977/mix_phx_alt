# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Plugs do
  import Phoenix.Controller
  import Plug.Conn

  # credo:disable-for-next-line Credo.Check.Readability.AliasAs
  alias Demo.Interface.Router.Helpers, as: Routes

  def fetch_current_user(conn, _opts) do
    {auth_token, conn} =
      if session_token = get_session(conn, :auth_token) do
        {session_token, conn}
      else
        conn = fetch_cookies(conn, signed: ["auth_token"])
        remember_token = conn.cookies["auth_token"]
        conn = if remember_token, do: put_session(conn, :auth_token, remember_token), else: conn
        {remember_token, conn}
      end

    current_user = auth_token && Demo.Core.User.authenticate(auth_token)

    assign(conn, :current_user, current_user)
  end

  def require_user(conn, _opts) do
    if conn.assigns.current_user,
      do: conn,
      else: conn |> redirect(to: Routes.user_path(conn, :login_form)) |> halt()
  end

  def require_anonymous(conn, _opts) do
    if is_nil(conn.assigns.current_user),
      do: conn,
      else: conn |> redirect(to: Routes.user_path(conn, :welcome)) |> halt()
  end
end
