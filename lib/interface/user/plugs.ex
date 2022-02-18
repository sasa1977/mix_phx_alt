# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.User.Plugs do
  import Phoenix.Controller
  import Plug.Conn

  # credo:disable-for-next-line Credo.Check.Readability.AliasAs
  alias Demo.Interface.Router.Helpers, as: Routes

  def fetch_current_user(conn, _opts) do
    user_token = get_session(conn, :user_token)
    current_user = user_token && Demo.Core.User.from_auth_token(user_token)
    assign(conn, :current_user, current_user)
  end

  def require_user(conn, _opts) do
    if conn.assigns.current_user,
      do: conn,
      else: conn |> redirect(to: Routes.user_path(conn, :registration_form)) |> halt()
  end

  def require_anonymous(conn, _opts) do
    if is_nil(conn.assigns.current_user),
      do: conn,
      else: conn |> redirect(to: Routes.user_path(conn, :welcome)) |> halt()
  end
end
