defmodule Plushie.Widget.Toggler do
  @moduledoc """
  Toggler -- on/off switch.

  ## Props

  - `is_toggled` (boolean) -- whether the toggler is on. Default: false.
  - `label` (string) -- text label displayed next to the toggler.
  - `spacing` (number) -- space between toggler and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Plushie.Type.Length`.
  - `size` (number) -- toggler size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Plushie.Type.Font`.
  - `line_height` (number | map) -- label line height.
  - `shaping` (atom) -- text shaping: `:basic`, `:advanced`, or `:auto`.
    See `Plushie.Type.Shaping`.
  - `wrapping` (atom) -- text wrapping: `:none`, `:word`, `:glyph`, `:word_or_glyph`.
    See `Plushie.Type.Wrapping`.
  - `text_alignment` (atom) -- horizontal label alignment: `:left`, `:center`, `:right`.
    See `Plushie.Type.Alignment`.
  - `style` (atom) -- named style. Currently only `:default`.
  - `disabled` (boolean) -- when true, the toggler cannot be toggled. Default: false.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  - `%WidgetEvent{type: :toggle, id: id, value: bool}` -- emitted on toggle, `value` is the new boolean state.
  """

  use Plushie.Widget

  widget(:toggler)

  field(:is_toggled, :boolean, option: false)
  field(:label, :string)
  field(:spacing, :float)
  field(:width, Plushie.Type.Length)
  field(:size, :float)
  field(:text_size, :float)
  field(:font, Plushie.Type.Font)
  field(:line_height, :any)
  field(:shaping, :atom)
  field(:wrapping, :atom)
  field(:text_alignment, :atom)
  field(:style, Plushie.Type.Style)
  field(:disabled, :boolean)

  positional([:is_toggled])
end
