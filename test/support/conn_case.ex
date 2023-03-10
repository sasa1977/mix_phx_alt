defmodule Demo.Test.ConnCase do
  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL

  using do
    quote do
      use Demo.Interface.Base.Routes

      import Plug.Conn
      import Phoenix.ConnTest
      import Demo.Test.ConnCase
      import Demo.Helpers

      # The default endpoint for testing
      @endpoint Demo.Interface.Endpoint
    end
  end

  setup tags do
    pid = SQL.Sandbox.start_owner!(Demo.Core.Repo, shared: not tags[:async])
    on_exit(fn -> SQL.Sandbox.stop_owner(pid) end)
  end

  @doc "Returns a string which starts with the given argument, and ends with a unique suffix."
  @spec unique(String.t()) :: String.t()
  def unique(prefix) do
    suffix = System.unique_integer([:monotonic, :positive]) |> Integer.to_string(36)
    "#{prefix}#{suffix}"
  end

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
