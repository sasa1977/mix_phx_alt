defmodule Demo.Core.Repo.Migrations.AlterTokensAllowUserNil do
  use Ecto.Migration

  def change do
    alter table(:tokens), do: modify(:user_id, :binary_id, null: true)
  end
end
