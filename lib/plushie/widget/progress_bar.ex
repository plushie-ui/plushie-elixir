defmodule Plushie.Widget.ProgressBar do
  @moduledoc """
  Progress bar -- displays progress within a range.

  ## Props

  - `range` (list) -- `[min, max]` as a two-element list. Default: `[0, 100]`.
  - `value` (number) -- current progress value. Default: 0.
  - `width` (length) -- bar width. Default: fill. See `Plushie.Type.Length`.
  - `height` (length) -- bar height. Default: shrink.
  - `style` -- named preset atom (`:primary` (default), `:secondary`, `:success`,
    `:danger`, `:warning`) or `StyleMap.t()` for custom styling.
    See `Plushie.Type.StyleMap`.
  - `vertical` (boolean) -- when `true`, renders the progress bar vertically.
  - `label` (string) -- accessible label for the progress bar (e.g.
    "Upload progress"). Sits outside the `a11y` object. See "Widget-specific
    accessibility props" in `docs/reference/accessibility.md`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  use Plushie.Widget

  widget(:progress_bar)

  field(:range, Plushie.Type.Range, option: false)
  field(:value, :float, option: false)
  field(:width, Plushie.Type.Length)
  field(:height, Plushie.Type.Length)
  field(:style, Plushie.Type.Style)
  field(:vertical, :boolean)
  field(:label, :string)

  positional([:range, :value])
end
