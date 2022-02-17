defmodule Demo.Test.ConnCase do
  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Demo.Test.ConnCase
      import Demo.Helpers

      # credo:disable-for-next-line Credo.Check.Readability.AliasAs
      alias Demo.Interface.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint Demo.Interface.Endpoint
    end
  end

  setup tags do
    pid = SQL.Sandbox.start_owner!(Demo.Core.Repo, shared: not tags[:async])
    on_exit(fn -> SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @spec unique(String.t()) :: String.t()
  def unique(prefix), do: "#{prefix}#{System.unique_integer([:monotonic, :positive])}"

  @spec changeset_errors(Ecto.Changeset.t()) :: %{atom => [String.t()]}
  def changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @spec changeset_errors(Ecto.Changeset.t(), atom) :: [String.t()]
  def changeset_errors(changeset, field_name),
    do: changeset |> changeset_errors() |> Map.get(field_name, [])
end
