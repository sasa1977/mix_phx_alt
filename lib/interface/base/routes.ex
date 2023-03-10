defmodule Demo.Interface.Base.Routes do
  defmacro __using__(_opts) do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Demo.Interface.Endpoint,
        router: Demo.Interface.Router,
        statics: unquote(static_paths())
    end
  end

  @spec static_paths :: [String.t()]
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
end
