defmodule Demo.Core.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table(:tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :hash, :binary, null: false
      add :type, :string, null: false
      timestamps(updated_at: false)
    end

    create unique_index(:tokens, [:type, :hash])
  end
end
