defmodule Demo.Core.PublicUrl do
  alias Demo.Core.User

  @type t :: String.t()

  @callback finish_registration(User.confirm_email_token()) :: t
  @callback change_email(User.confirm_email_token()) :: t

  @spec finish_registration(User.confirm_email_token()) :: t
  def finish_registration(token), do: impl().finish_registration(token)

  @spec change_email(User.confirm_email_token()) :: t
  def change_email(token), do: impl().change_email(token)

  @doc false
  @spec configure(module) :: :ok
  def configure(impl),
    do: :persistent_term.put({__MODULE__, :impl}, impl)

  defp impl, do: :persistent_term.get({__MODULE__, :impl})
end
