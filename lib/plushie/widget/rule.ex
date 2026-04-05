defmodule Plushie.Widget.Rule do
  @moduledoc """
  Horizontal or vertical rule (divider line).

  ## Props

  - `height` (number) -- line thickness in pixels (for horizontal rules). Default: 1.
  - `width` (number) -- line thickness in pixels (for vertical rules). Also accepts `thickness`.
  - `direction` -- `:horizontal` (default) or `:vertical`. See `Plushie.Type.Direction`.
  - `style` -- named preset atom (`:default`, `:weak`) or `StyleMap.t()` for
    custom styling. See `Plushie.Type.StyleMap`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  use Plushie.Widget

  widget(:rule)

  field(:height, :float)
  field(:width, :float)
  field(:direction, :atom)
  field(:style, Plushie.Type.Style)
end
