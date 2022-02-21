defmodule Demo.Core.Model.Token do
  use Demo.Core.Model.Base

  @all [
    auth: 60,
    confirm_email: 7,
    password_reset: 1
  ]

  # generates @type :: auth | confirm_email | ... from the `@all` definition
  @type type :: unquote(Enum.reduce(Keyword.keys(@all), &quote(do: unquote(&1) | unquote(&2))))

  schema "tokens" do
    field :hash, :binary
    field :type, Ecto.Enum, values: Keyword.keys(@all)
    field :payload, :map

    belongs_to :user, Model.User

    timestamps(updated_at: false)
  end

  @spec validities :: [{type, days :: pos_integer()}]
  def validities, do: @all

  for {type, validity} <- @all do
    @spec validity(unquote(type)) :: unquote(validity)
    def validity(unquote(type)), do: unquote(validity)
  end
end
