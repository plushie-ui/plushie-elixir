defmodule Plushie.Widget.Svg do
  @moduledoc """
  SVG display, renders a vector image from a file path.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :image}

  widget :svg do
    field :source, :string, option: false, doc: "Path to the SVG file."
    field :width, Plushie.Type.Length, doc: "SVG width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "SVG height. Default: shrink."
    field :content_fit, Plushie.Type.ContentFit, doc: "How the SVG fits its bounds."
    field :rotation, :float, doc: "Rotation angle in degrees."
    field :opacity, :float, doc: "Opacity from 0.0 (transparent) to 1.0 (opaque)."
    field :color, Plushie.Type.Color, doc: "Color tint applied to the SVG."
    field :alt, :string, doc: "Accessible label for the SVG."
    field :description, :string, doc: "Extended accessible description for the SVG."
    field :decorative, :boolean, doc: "When true, hides the SVG from assistive technology."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."

    positional [:source]
  end
end
