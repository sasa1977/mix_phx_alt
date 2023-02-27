defmodule Demo.Interface.PublicUrl do
  @behaviour Demo.Core.PublicUrl

  alias Demo.Core

  # credo:disable-for-next-line Credo.Check.Readability.AliasAs
  alias Demo.Interface.Router.Helpers, as: Routes

  @impl Core.PublicUrl
  def finish_registration(token),
    do: Routes.user_url(Demo.Interface.Endpoint, :finish_registration_form, token)
end
