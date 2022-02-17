defmodule Demo.Interface.Auth do
  @spec set_token(Plug.Conn.t(), Demo.Core.User.token()) :: Plug.Conn.t()
  def set_token(conn, token),
    do: Plug.Conn.put_session(conn, :user_token, token)

  @spec fetch_current_user(Plug.Conn.t(), any) :: Plug.Conn.t()
  def fetch_current_user(conn, _opts) do
    user_token = Plug.Conn.get_session(conn, :user_token)
    current_user = user_token && Demo.Core.User.from_auth_token(user_token)
    Plug.Conn.assign(conn, :current_user, current_user)
  end

  @spec current_user(Plug.Conn.t()) :: Demo.Core.Model.User.t() | nil
  def current_user(conn), do: conn.assigns.current_user
end
