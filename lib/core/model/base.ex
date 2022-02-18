defmodule Demo.Core.Model.Base do
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      alias Demo.Core.Model

      @type t :: %__MODULE__{}

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime_usec]
    end
  end
end
