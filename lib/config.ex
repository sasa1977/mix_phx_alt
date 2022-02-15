defmodule Demo.Config do
  use Boundary

  @doc """
  Returns the mix environment in which the project has been compiled.

  This function can safely be used at runtime.
  """
  @spec mix_env :: :dev | :test | :prod
  def mix_env, do: Application.fetch_env!(:demo, :mix_env)
end
