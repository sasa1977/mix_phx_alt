defmodule Demo.Interface do
  use Boundary, exports: [Endpoint], deps: [Demo.Core]
end
