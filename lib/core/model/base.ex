defmodule Demo.Core.Model.Base do
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      alias Demo.Core.Model

      @type t :: %__MODULE__{}
    end
  end
end
