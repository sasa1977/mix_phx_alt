defmodule Demo.Interface.ErrorViewTest do
  use Demo.Interface.ConnCase, async: true
  import Phoenix.View

  test "renders 404.html" do
    assert render_to_string(Demo.Interface.ErrorView, "404.html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(Demo.Interface.ErrorView, "500.html", []) == "Internal Server Error"
  end
end
