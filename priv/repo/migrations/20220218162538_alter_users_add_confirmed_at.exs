defmodule Demo.Core.Repo.Migrations.AlterUsersAddConfirmedAt do
  use Ecto.Migration

  def change do
    alter table(:users), do: add(:confirmed_at, :utc_datetime_usec, null: true)
  end
end
