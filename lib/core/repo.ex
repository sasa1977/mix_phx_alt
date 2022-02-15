defmodule Demo.Core.Repo do
  use Ecto.Repo,
    otp_app: :demo,
    adapter: Ecto.Adapters.Postgres
end
