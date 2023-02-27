defmodule Demo.Core.PublicUrl do
  alias Demo.Core.User

  @type t :: String.t()

  @callback finish_registration_form(User.confirm_email_token()) :: t
  @callback change_email(User.confirm_email_token()) :: t
  @callback reset_password_form(User.password_reset_token()) :: t

  @spec finish_registration_form(User.confirm_email_token()) :: t
  def finish_registration_form(token), do: impl().finish_registration_form(token)

  @spec change_email(User.confirm_email_token()) :: t
  def change_email(token), do: impl().change_email(token)

  @spec reset_password_form(User.password_reset_token()) :: t
  def reset_password_form(token), do: impl().reset_password_form(token)

  @doc false
  @spec configure(module) :: :ok
  def configure(impl),
    do: :persistent_term.put({__MODULE__, :impl}, impl)

  defp impl, do: :persistent_term.get({__MODULE__, :impl})
end
