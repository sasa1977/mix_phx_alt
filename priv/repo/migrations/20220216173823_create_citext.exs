defmodule Demo.Core.Repo.Migrations.CreateCitext do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION citext", "DROP EXTENSION citext"
  end
end
