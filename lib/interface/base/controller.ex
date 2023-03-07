defmodule Demo.Interface.Base.Controller do
  defmacro __using__(_opts) do
    quote do
      use Phoenix.Controller, formats: [html: "Html"], layouts: [html: Demo.Interface.Layout.Html]
      use Demo.Interface.Routes

      import Demo.Interface.User.Auth
      import Plug.Conn

      action_fallback Demo.Interface.Error.Controller
    end
  end
end
