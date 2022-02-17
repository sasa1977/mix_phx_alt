defmodule Demo.Core.Model.Token do
  use Ecto.Schema
  alias Demo.Core.Model

  @type t :: %__MODULE__{}

  schema "tokens" do
    field :hash, :binary
    field :type, Ecto.Enum, values: [:auth]
    belongs_to :user, Model.User

    timestamps(updated_at: false)
  end
end
