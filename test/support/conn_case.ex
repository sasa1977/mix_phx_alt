defmodule DemoWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import DemoWeb.ConnCase

      # credo:disable-for-next-line Credo.Check.Readability.AliasAs
      alias DemoWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint DemoWeb.Endpoint
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Demo.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
