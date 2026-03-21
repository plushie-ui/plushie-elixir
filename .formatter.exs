# Paren-free formatting for layout/container macros that use do-blocks.
# These read like declarative markup:
#
#   window "main", title: "Counter" do
#     column padding: 8 do
#       ...
#     end
#   end
#
# Leaf widgets (button, text, checkbox, etc.) keep parens for clarity
# and visual consistency with each other.
#
# Consumers pull this in via `import_deps: [:toddy]` in their .formatter.exs.

toddy_ui_locals = [
  canvas: 1,
  canvas: 2,
  canvas: 3,
  column: :*,
  container: 1,
  container: 2,
  container: 3,
  floating: 1,
  floating: 2,
  floating: 3,
  grid: :*,
  group: :*,
  keyed_column: :*,
  layer: 2,
  mouse_area: 1,
  mouse_area: 2,
  mouse_area: 3,
  overlay: 1,
  overlay: 2,
  overlay: 3,
  pane_grid: 1,
  pane_grid: 2,
  pane_grid: 3,
  pin: 1,
  pin: 2,
  pin: 3,
  responsive: :*,
  row: :*,
  scrollable: 1,
  scrollable: 2,
  scrollable: 3,
  sensor: 1,
  sensor: 2,
  sensor: 3,
  stack: :*,
  table: 1,
  table: 2,
  table: 3,
  themer: 1,
  themer: 2,
  themer: 3,
  tooltip: 1,
  tooltip: 2,
  tooltip: 3,
  window: 1,
  window: 2,
  window: 3
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: toddy_ui_locals,
  export: [
    locals_without_parens: toddy_ui_locals
  ]
]
