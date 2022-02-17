defmodule Demo.Helpers do
  use Boundary

  @spec validate(true, any) :: :ok
  @spec validate(false, reason) :: {:error, reason} when reason: var
  def validate(true, _reason), do: :ok
  def validate(false, reason), do: {:error, reason}
end
