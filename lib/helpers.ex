defmodule Demo.Helpers do
  use Boundary

  @spec validate(true) :: :ok
  @spec validate(false) :: :error
  def validate(true), do: :ok
  def validate(false), do: :error

  @spec validate(true, any) :: :ok
  @spec validate(false, reason) :: {:error, reason} when reason: var
  def validate(true, _reason), do: :ok
  def validate(false, reason), do: {:error, reason}

  @spec mix_env :: :dev | :test | :prod
  def mix_env, do: Application.fetch_env!(:demo, :mix_env)

  @spec empty_changeset :: Ecto.Changeset.t()
  def empty_changeset, do: Ecto.Changeset.change({%{}, %{}})

  @spec transfer_changeset_errors(Ecto.Changeset.t(), Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def transfer_changeset_errors(%Ecto.Changeset{valid?: false} = from, to),
    do: %Ecto.Changeset{to | errors: from.errors, valid?: false}

  @spec ok!({:ok, result}) :: result when result: var
  def ok!({:ok, result}), do: result
end
