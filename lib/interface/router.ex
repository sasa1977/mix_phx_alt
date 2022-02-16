defmodule Demo.Interface.Router do
  use Phoenix.Router

  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {Demo.Interface.Layout.View, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Demo.Interface do
    pipe_through :browser

    get "/", Page.Controller, :index, as: :page

    get "/registration_form", User.Controller, :registration_form, as: :user
    post "/register", User.Controller, :register, as: :user

    # test-only route for testing server error
    if Mix.env() == :test do
      get "/server_error", Page.Controller, :server_error
    end
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: Demo.Interface.Telemetry
    end
  end
end
