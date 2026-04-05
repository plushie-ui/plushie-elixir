defmodule Plushie.Widget.Checkbox do
  @moduledoc """
  Checkbox -- toggleable boolean input.

  ## Props

  - `checked` (boolean) -- whether the checkbox is checked. Default: false.
  - `label` (string) -- text label displayed next to the checkbox.
  - `spacing` (number) -- space between checkbox and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Plushie.Type.Length`.
  - `size` (number) -- checkbox size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Plushie.Type.Font`.
  - `line_height` (number | map) -- label line height.
  - `shaping` -- text shaping strategy. See `Plushie.Type.Shaping`.
  - `wrapping` -- text wrapping mode. See `Plushie.Type.Wrapping`.
  - `style` -- named preset (`:primary` (default), `:secondary`, `:success`,
    `:danger`) or `StyleMap.t()`. See `Plushie.Type.StyleMap`.
  - `icon` (map) -- custom icon for the check mark. Map with `:code_point` (required),
    and optional `:size`, `:line_height`, `:font`, `:shaping`.
  - `disabled` (boolean) -- when true, the checkbox cannot be toggled. Default: false.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  - `%WidgetEvent{type: :toggle, id: id, value: bool}` -- emitted on toggle, `value` is the new boolean state.
  """

  use Plushie.Widget

  widget(:checkbox)

  field(:label, :string)
  field(:is_toggled, :boolean, option: false, wire_name: :checked)
  field(:spacing, :float)
  field(:width, Plushie.Type.Length)
  field(:size, :float)
  field(:text_size, :float)
  field(:font, Plushie.Type.Font)
  field(:line_height, :any)
  field(:shaping, :atom)
  field(:wrapping, :atom)
  field(:style, Plushie.Type.Style)
  field(:icon, :map)
  field(:disabled, :boolean)

  positional([:label, :is_toggled])
end
