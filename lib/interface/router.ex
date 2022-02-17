defmodule Demo.Interface.Router do
  use Phoenix.Router

  import Demo.Interface.User.Plugs
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

    get "/registration_form", User.Controller, :registration_form, as: :user
    post "/register", User.Controller, :register, as: :user
  end

  # logged-in routes
  scope "/", Demo.Interface do
    pipe_through [:browser, :require_user]

    get "/", User.Controller, :welcome, as: :user
    delete "/logout", User.Controller, :logout, as: :user
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: Demo.Interface.Telemetry
    end
  end
end
