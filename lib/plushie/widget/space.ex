defmodule Plushie.Widget.Space do
  @moduledoc """
  Empty space -- invisible spacer widget.

  ## Props

  - `width` (length) -- space width. Default: shrink. See `Plushie.Type.Length`.
  - `height` (length) -- space height. Default: shrink.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  use Plushie.Widget

  widget(:space)

  field(:width, Plushie.Type.Length)
  field(:height, Plushie.Type.Length)
end
