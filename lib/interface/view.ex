defmodule Demo.Interface.View do
  defmacro __using__(opts) do
    quote do
      default_opts = [
        root: Path.relative_to_cwd(__DIR__),
        path: "templates"
      ]

      use Phoenix.View, Keyword.merge(default_opts, unquote(opts))
      use Phoenix.HTML
      use Demo.Interface.Routes

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      import Phoenix.Component
      import Phoenix.LiveView.Helpers
      import Phoenix.View
      import Demo.Interface.View.Helpers

      # credo:disable-for-next-line Credo.Check.Readability.AliasAs
      alias Demo.Interface.Router.Helpers, as: Routes
    end
  end
end
