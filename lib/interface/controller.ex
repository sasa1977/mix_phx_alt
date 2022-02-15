defmodule Demo.Interface.Controller do
  defmacro __using__(_opts) do
    quote do
      use Phoenix.Controller, namespace: Demo.Interface

      import Plug.Conn

      # credo:disable-for-next-line Credo.Check.Readability.AliasAs
      alias Demo.Interface.Router.Helpers, as: Routes
    end
  end
end
