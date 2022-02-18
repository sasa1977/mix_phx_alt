defmodule Demo.Core.Model.Token do
  use Demo.Core.Model.Base

  schema "tokens" do
    field :hash, :binary
    field :type, Ecto.Enum, values: [:auth]
    belongs_to :user, Model.User

    timestamps(updated_at: false)
  end

  @spec valid?(t) :: boolean
  def valid?(%__MODULE__{type: :auth} = token) do
    sixty_days_in_sec = 60 * 24 * 60 * 60
    DateTime.diff(DateTime.utc_now(), token.inserted_at, :second) < sixty_days_in_sec
  end
end
