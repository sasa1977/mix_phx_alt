# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Demo.Interface.Error.View do
  use Demo.Interface.View

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
