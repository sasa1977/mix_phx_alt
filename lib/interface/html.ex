defmodule Demo.Interface.HTML do
  defmacro __using__(_opts) do
    quote do
      use Phoenix.Component
      use Demo.Interface.Routes

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      import Phoenix.HTML

      import Demo.Interface.CoreComponents

      alias Phoenix.LiveView.JS
    end
  end
end
