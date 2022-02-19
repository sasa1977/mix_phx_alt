defmodule Demo.Core.Model.User do
  use Demo.Core.Model.Base

  schema "users" do
    field :email, :string
    field :password_hash, :string, redact: true
    field :confirmed_at, :utc_datetime_usec

    timestamps()
  end
end
