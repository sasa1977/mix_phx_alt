defmodule Demo.Interface.Base.Browser do
  use Plug.Builder

  import Demo.Interface.User.Auth
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :fetch_current_user
  plug :put_root_layout, html: {Demo.Interface.Layout.Html, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
end
