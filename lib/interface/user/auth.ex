# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Auth do
  import Phoenix.Controller
  import Plug.Conn

  # credo:disable-for-next-line Credo.Check.Readability.AliasAs
  alias Demo.Interface.Router.Helpers, as: Routes

  @spec token(Plug.Conn.t()) :: Demo.Core.User.auth_token() | nil
  def token(conn), do: get_session(conn, :auth_token)

  @doc "Clear the session and remember cookie"
  def clear(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> delete_resp_cookie("auth_token")
    |> assign(:current_user, nil)
  end

  @doc "Sets the authentication token, and optionally also stores it in a remember cookie."
  @spec set(Plug.Conn.t(), Demo.Core.User.auth_token(), remember_me?: boolean) :: Plug.Conn.t()
  def set(conn, auth_token, opts \\ []) do
    conn
    |> clear()
    |> put_session(:auth_token, auth_token)
    |> then(fn conn ->
      if Keyword.get(opts, :remember_me?, false) do
        put_resp_cookie(conn, "auth_token", auth_token,
          sign: true,
          max_age: Demo.Core.Model.Token.validity(:auth) * 24 * 60 * 60,
          same_site: "Lax"
        )
      else
        conn
      end
    end)
  end

  # ------------------------------------------------------------------------
  # Plugs
  # ------------------------------------------------------------------------

  def fetch_current_user(conn, _opts) do
    {auth_token, conn} =
      if session_token = token(conn) do
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
