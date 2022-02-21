defmodule Demo.Core.Repo.Migrations.CreatePgcryptoExtension do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION pgcrypto", "DROP EXTENSION pgcrypto"
  end
end
