defmodule Demo.Interface.Layout.View do
  use Demo.Interface.View

  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}
end
