defmodule Demo.Interface.LayoutView do
  use Demo.Interface, :view

  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}
end
