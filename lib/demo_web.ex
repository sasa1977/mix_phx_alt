# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule DemoWeb do
  def controller do
    quote do
      use Phoenix.Controller, namespace: DemoWeb

      import Plug.Conn
      # credo:disable-for-next-line Credo.Check.Readability.AliasAs
      alias DemoWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/demo_web/templates",
        namespace: DemoWeb

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {DemoWeb.LayoutView, "live.html"}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defp view_helpers do
    quote do
      use Phoenix.HTML

      import Phoenix.LiveView.Helpers

      import Phoenix.View

      import DemoWeb.ErrorHelpers

      # credo:disable-for-next-line Credo.Check.Readability.AliasAs
      alias DemoWeb.Router.Helpers, as: Routes
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
