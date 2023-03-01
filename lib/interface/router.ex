defmodule Demo.Interface.Router do
  use Phoenix.Router

  import Demo.Interface.User.Auth
  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :fetch_current_user
    plug :put_root_layout, {Demo.Interface.Layout.View, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Demo.Interface do
    pipe_through [:browser]

    get "/", User.Controller, :welcome

    # registration
    get "/start_registration", User.Controller, :start_registration_form
    post "/start_registration", User.Controller, :start_registration
    get "/finish_registration/:token", User.Controller, :finish_registration_form
    post "/finish_registration/:token", User.Controller, :finish_registration

    # login/logout
    get "/login", User.Controller, :login_form
    post "/login", User.Controller, :login
    post "/logout", User.Controller, :logout

    # password reset
    get "/start_password_reset", User.Controller, :start_password_reset_form
    post "/start_password_reset", User.Controller, :start_password_reset
    get "/reset_password/:token", User.Controller, :reset_password_form
    post "/reset_password/:token", User.Controller, :reset_password

    # settings
    get "/settings", User.Controller, :settings
    post "/change_password", User.Controller, :change_password
    post "/start_email_change", User.Controller, :start_email_change
    get "/change_email/:token", User.Controller, :change_email
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: Demo.Interface.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
