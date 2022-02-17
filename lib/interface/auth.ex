defmodule Demo.Interface.Auth do
  @spec set_token(Plug.Conn.t(), Demo.Core.User.token()) :: Plug.Conn.t()
  def set_token(conn, token),
    do: Plug.Conn.put_session(conn, :user_token, token)
end
