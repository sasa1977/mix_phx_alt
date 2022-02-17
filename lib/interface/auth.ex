defmodule Demo.Interface.Auth do
  import Phoenix.Controller
  import Plug.Conn

  # credo:disable-for-next-line Credo.Check.Readability.AliasAs
  alias Demo.Interface.Router.Helpers, as: Routes

  @spec set_token(Plug.Conn.t(), Demo.Core.User.token()) :: Plug.Conn.t()
  def set_token(conn, token),
    do: put_session(conn, :user_token, token)

  @spec fetch_current_user(Plug.Conn.t(), any) :: Plug.Conn.t()
  def fetch_current_user(conn, _opts) do
    user_token = get_session(conn, :user_token)
    current_user = user_token && Demo.Core.User.from_auth_token(user_token)
    assign(conn, :current_user, current_user)
  end

  @spec current_user(Plug.Conn.t()) :: Demo.Core.Model.User.t() | nil
  def current_user(conn), do: conn.assigns.current_user

  @spec require_user(Plug.Conn.t(), any) :: Plug.Conn.t()
  def require_user(conn, _opts) do
    if conn.assigns.current_user,
      do: conn,
      else: conn |> redirect(to: Routes.user_path(conn, :registration_form)) |> halt()
  end

  @spec require_anonymous(Plug.Conn.t(), any) :: Plug.Conn.t()
  def require_anonymous(conn, _opts) do
    if is_nil(conn.assigns.current_user),
      do: conn,
      else: conn |> redirect(to: Routes.user_path(conn, :welcome)) |> halt()
  end
end
