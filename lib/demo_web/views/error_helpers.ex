defmodule DemoWeb.ErrorHelpers do
  use Phoenix.HTML

  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      message =
        with {msg, opts} <- error do
          Regex.replace(
            ~r"%{(\w+)}",
            msg,
            fn _, key -> opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string() end
          )
        end

      content_tag(:span, message,
        class: "invalid-feedback",
        phx_feedback_for: input_name(form, field)
      )
    end)
  end
end
