defmodule Plushie.Canvas.Group do
  @moduledoc """
  Canvas group: a structural container for transforms, clips, and
  visual grouping.

  Groups carry an ordered `transforms` list and an optional `clip`
  rect. The optional `id` is for tree diffing and targeting, not
  interactivity.

  For interactive canvas elements (click, hover, drag, focus, a11y),
  use `Plushie.Canvas.Interactive` via the `interactive` macro.
  """

  use Plushie.Canvas.Element

  element :group, container: true do
    field :transforms, :any
    field :clip, :any
  end
end
