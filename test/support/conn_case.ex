defmodule Demo.Interface.ConnCase do
  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Demo.Interface.ConnCase

      # credo:disable-for-next-line Credo.Check.Readability.AliasAs
      alias Demo.Interface.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint Demo.Interface.Endpoint
    end
  end

  setup tags do
    pid = SQL.Sandbox.start_owner!(Demo.Repo, shared: not tags[:async])
    on_exit(fn -> SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
