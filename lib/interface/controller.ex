defmodule Demo.Interface.Controller do
  defmacro __using__(_opts) do
    quote do
      use Phoenix.Controller

      import Plug.Conn

      # credo:disable-for-next-line Credo.Check.Readability.AliasAs
      alias Demo.Interface.Router.Helpers, as: Routes

      plug :put_layout, {Demo.Interface.Layout.View, :app}

      action_fallback Demo.Interface.Error.Controller
    end
  end
end
