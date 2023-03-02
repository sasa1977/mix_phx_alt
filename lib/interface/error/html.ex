# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.Error.HTML do
  use Demo.Interface.HTML

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
