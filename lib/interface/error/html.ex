# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.Error.Html do
  use Demo.Interface.Html

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
