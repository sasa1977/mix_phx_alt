defmodule Demo.Interface.Controller do
  defmacro __using__(_opts) do
    quote do
      use Phoenix.Controller, formats: [:html]
      use Demo.Interface.Routes

      import Demo.Interface.User.Auth
      import Plug.Conn

      plug :put_layout, {Demo.Interface.Layout.View, :app}

      action_fallback Demo.Interface.Error.Controller
    end
  end
end
