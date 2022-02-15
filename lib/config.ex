defmodule Demo.Config do
  use Boundary

  @doc """
  Returns the mix environment in which the project has been compiled.

  This function can safely be used at runtime.
  """
  @spec mix_env :: :dev | :test | :prod
  def mix_env, do: Application.fetch_env!(:demo, :mix_env)

  @spec secret_key_base :: String.t()
  def secret_key_base, do: os_env("SECRET_KEY_BASE")

  @spec site_host :: String.t()
  def site_host, do: os_env("SITE_HOST")

  defp os_env(name), do: System.get_env(name) || default(name, mix_env())

  defp default("SITE_HOST", mix_env) when mix_env in ~w/dev test/a, do: "localhost"

  defp default("SECRET_KEY_BASE", mix_env) when mix_env in ~w/dev test/a,
    do: "6SQyoN0wWViSTd5UaarW/wZsqTX0sFgYqYfGZpehG2s6kCwJOSiVVaiLBUO5oUdB"

  defp default(var, _mix_env), do: raise("#{var} environment variable is not set")
end
