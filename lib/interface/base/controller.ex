defmodule Demo.Interface.Base.Controller do
  defmacro __using__(_opts) do
    quote do
      use Phoenix.Controller, formats: [html: "Html"], layouts: [html: Demo.Interface.Layout.Html]
      use Demo.Interface.Base.Routes

      import Demo.Interface.User.Auth

      plug Demo.Interface.Base.Browser

      action_fallback Demo.Interface.Error.Controller
    end
  end
end
