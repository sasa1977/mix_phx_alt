defmodule Demo.Core.Model.User do
  use Demo.Core.Model.Base

  schema "users" do
    field :email, :string
    field :password_hash, :string, redact: true

    timestamps()
  end
end
