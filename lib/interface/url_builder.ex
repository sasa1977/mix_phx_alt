defmodule Demo.Interface.UrlBuilder do
  @behaviour Demo.Core.UrlBuilder

  use Demo.Interface.Routes

  alias Demo.Core
  alias Demo.Interface.Endpoint

  @impl Core.UrlBuilder
  def finish_registration_form(token),
    do: url(Endpoint, ~p"/finish_registration/#{token}")

  @impl Core.UrlBuilder
  def change_email(token), do: url(Endpoint, ~p"/change_email/#{token}")

  @impl Core.UrlBuilder
  def reset_password_form(token), do: url(Endpoint, ~p"/reset_password/#{token}")
end
