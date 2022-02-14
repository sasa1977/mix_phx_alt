defmodule DemoWeb.ErrorHelpers do
  use Phoenix.HTML

  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, translate_error(error),
        class: "invalid-feedback",
        phx_feedback_for: input_name(form, field)
      )
    end)
  end

  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(DemoWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(DemoWeb.Gettext, "errors", msg, opts)
    end
  end
end
