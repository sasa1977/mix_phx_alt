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

  # anonymous routes
  scope "/", Demo.Interface do
    pipe_through [:browser, :require_anonymous]

    get "/start_registration", User.Controller, :start_registration_form, as: :user
    post "/start_registration", User.Controller, :start_registration, as: :user

    get "/finish_registration/:token", User.Controller, :finish_registration_form, as: :user
    post "/finish_registration/:token", User.Controller, :finish_registration, as: :user

    get "/login", User.Controller, :login_form, as: :user
    post "/login", User.Controller, :login, as: :user

    get "/start_password_reset", User.Controller, :start_password_reset_form, as: :user
    post "/start_password_reset", User.Controller, :start_password_reset, as: :user

    get "/reset_password/:token", User.Controller, :reset_password_form, as: :user
    post "/reset_password/:token", User.Controller, :reset_password, as: :user
  end

  # logged-in routes
  scope "/", Demo.Interface do
    pipe_through [:browser, :require_user]

    get "/", User.Controller, :welcome, as: :user
    delete "/logout", User.Controller, :logout, as: :user

    get "/settings", User.Controller, :settings, as: :user
    post "/change_password", User.Controller, :change_password, as: :user

    post "/start_email_change", User.Controller, :start_email_change, as: :user
  end

  # auth-status independent routes
  scope "/", Demo.Interface do
    pipe_through [:browser]

    get "/change_email/:token", User.Controller, :change_email, as: :user
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
