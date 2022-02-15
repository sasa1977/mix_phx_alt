defmodule Demo.Interface.Router do
  use Demo.Interface, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {Demo.Interface.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Demo.Interface do
    pipe_through :browser

    get "/", PageController, :index

    # test-only route for testing server error
    if Mix.env() == :test do
      get "/server_error", PageController, :server_error
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
