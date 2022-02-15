defmodule Demo.Interface.View do
  defmacro __using__(opts) do
    quote do
      default_opts = [
        root: Path.relative_to_cwd(__DIR__),
        path: "templates",
        namespace: Demo.Interface
      ]

      use Phoenix.View, Keyword.merge(default_opts, unquote(opts))

      use Phoenix.HTML

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      import Phoenix.LiveView.Helpers
      import Phoenix.View
      import Demo.Interface.ErrorHelpers

      # credo:disable-for-next-line Credo.Check.Readability.AliasAs
      alias Demo.Interface.Router.Helpers, as: Routes
    end
  end
end
