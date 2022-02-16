defmodule Demo.Core.Model.User do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "users" do
    field :email, :string
    field :password_hash, :string, redact: true

    timestamps()
  end
end
