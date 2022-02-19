defmodule Demo.Core.Model.Token do
  use Demo.Core.Model.Base

  schema "tokens" do
    field :hash, :binary
    field :type, Ecto.Enum, values: [:auth, :confirm_email]
    field :payload, :map

    belongs_to :user, Model.User

    timestamps(updated_at: false)
  end
end
