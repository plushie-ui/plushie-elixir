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
# Consumers pull this in via `import_deps: [:plushie]` in their .formatter.exs.

plushie_ui_locals = [
  button: 2,
  button: 3,
  canvas: 1,
  canvas: 2,
  canvas: 3,
  checkbox: 2,
  checkbox: 3,
  circle: 3,
  circle: 4,
  column: :*,
  combo_box: 3,
  combo_box: 4,
  container: 1,
  container: 2,
  container: 3,
  floating: 1,
  floating: 2,
  floating: 3,
  grid: :*,
  group: :*,
  image: 2,
  image: 3,
  keyed_column: :*,
  layer: 2,
  line: 4,
  line: 5,
  pointer_area: 1,
  pointer_area: 2,
  pointer_area: 3,
  overlay: 1,
  overlay: 2,
  overlay: 3,
  pane_grid: 1,
  pane_grid: 2,
  pane_grid: 3,
  path: 1,
  path: 2,
  pick_list: 3,
  pick_list: 4,
  pin: 1,
  pin: 2,
  pin: 3,
  qr_code: 2,
  qr_code: 3,
  radio: 3,
  radio: 4,
  rect: 4,
  rect: 5,
  responsive: :*,
  rich_text: 1,
  rich_text: 2,
  row: :*,
  scrollable: 1,
  scrollable: 2,
  scrollable: 3,
  sensor: 1,
  sensor: 2,
  sensor: 3,
  slider: 3,
  slider: 4,
  stack: :*,
  stroke: 2,
  stroke: 3,
  svg: 2,
  svg: 3,
  table: 1,
  table: 2,
  table: 3,
  text: 3,
  text: 4,
  text_editor: 2,
  text_editor: 3,
  text_input: 2,
  text_input: 3,
  themer: 1,
  themer: 2,
  themer: 3,
  toggler: 2,
  toggler: 3,
  tooltip: 1,
  tooltip: 2,
  tooltip: 3,
  vertical_slider: 3,
  vertical_slider: 4,
  window: 1,
  window: 2,
  window: 3
]

# Widget and type declaration macros (used in module definitions).
plushie_declaration_locals = [
  widget: 1,
  widget: 2,
  field: 2,
  field: 3,
  positional: 1,
  event: 1,
  event: 2,
  state: 1,
  state: 2,
  command: 1,
  command: 2,
  enum: 1,
  union: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: plushie_ui_locals ++ plushie_declaration_locals,
  export: [
    locals_without_parens: plushie_ui_locals ++ plushie_declaration_locals
  ]
]
