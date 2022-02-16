defmodule Demo.Release do
  use Boundary

  @spec migrate :: :ok
  def migrate do
    Application.load(:demo)

    for repo <- repos(),
        do: {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))

    :ok
  end

  defp repos, do: Application.fetch_env!(:demo, :ecto_repos)
end
