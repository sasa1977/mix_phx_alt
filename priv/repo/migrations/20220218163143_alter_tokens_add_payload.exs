defmodule Demo.Core.Repo.Migrations.AlterTokensAddPayload do
  use Ecto.Migration

  def change do
    alter table(:tokens), do: add(:payload, :map, null: false, default: %{})
  end
end
