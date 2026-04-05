defmodule Plushie.Widget.Stack do
  @moduledoc """
  Stack layout, layers children on top of each other.
  """

  use Plushie.Widget

  widget :stack, container: true do
    field :width, Plushie.Type.Length, doc: "Stack width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Stack height. Default: shrink."
    field :clip, :boolean, doc: "Clip children that overflow. Default: false."
  end
end
