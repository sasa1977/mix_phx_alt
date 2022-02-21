defmodule Demo.Core.Model.Token do
  use Demo.Core.Model.Base

  @type type :: :auth | :confirm_email | :password_reset

  schema "tokens" do
    field :hash, :binary
    field :type, Ecto.Enum, values: [:auth, :confirm_email, :password_reset]
    field :payload, :map

    belongs_to :user, Model.User

    timestamps(updated_at: false)
  end

  @spec validities :: [{type, days :: pos_integer()}]
  def validities do
    [
      auth: 60,
      confirm_email: 7,
      password_reset: 1
    ]
  end

  @spec validity(type) :: pos_integer
  def validity(type), do: Keyword.fetch!(validities(), type)
end
