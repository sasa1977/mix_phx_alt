defmodule Demo.Helpers do
  use Boundary

  @spec mix_env :: :dev | :test | :prod
  def mix_env, do: Application.fetch_env!(:demo, :mix_env)

  @spec ok!({:ok, result}) :: result when result: var
  def ok!({:ok, result}), do: result

  @spec validate(true) :: :ok
  @spec validate(false) :: :error
  def validate(true), do: :ok
  def validate(false), do: :error

  @spec validate(true, any) :: :ok
  @spec validate(false, reason) :: {:error, reason} when reason: var
  def validate(true, _reason), do: :ok
  def validate(false, reason), do: {:error, reason}

  @spec empty_changeset :: Ecto.Changeset.t()
  def empty_changeset, do: Ecto.Changeset.change({%{}, %{}}, %{})

  @spec validate_field(Ecto.Changeset.t(), atom, (any -> String.t() | nil)) ::
          Ecto.Changeset.t()
  def validate_field(changeset, field, validator) do
    if error = validator.(Ecto.Changeset.get_field(changeset, field)),
      do: Ecto.Changeset.add_error(changeset, field, error),
      else: changeset
  end
end
