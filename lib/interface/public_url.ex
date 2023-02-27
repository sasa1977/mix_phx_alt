defmodule Demo.Interface.PublicUrl do
  @behaviour Demo.Core.PublicUrl

  alias Demo.Core
  alias Demo.Interface.Endpoint

  # credo:disable-for-next-line Credo.Check.Readability.AliasAs
  alias Demo.Interface.Router.Helpers, as: Routes

  @impl Core.PublicUrl
  def finish_registration_form(token),
    do: Routes.user_url(Endpoint, :finish_registration_form, token)

  @impl Core.PublicUrl
  def change_email(token), do: Routes.user_url(Endpoint, :change_email, token)

  @impl Core.PublicUrl
  def reset_password_form(token), do: Routes.user_url(Endpoint, :reset_password_form, token)
end
