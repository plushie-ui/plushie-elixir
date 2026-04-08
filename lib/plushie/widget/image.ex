defmodule Plushie.Widget.Image do
  @moduledoc """
  Image display, renders a raster image from a file path or an in-memory handle.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :image}

  widget :image do
    field :source, :any,
      option: false,
      doc: "Path to the image file, or `%{handle: name}` for in-memory images."

    field :width, Plushie.Type.Length, doc: "Image width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Image height. Default: shrink."
    field :content_fit, Plushie.Type.ContentFit, doc: "How the image fits its bounds."
    field :rotation, :float, doc: "Rotation angle in degrees."
    field :opacity, :float, doc: "Opacity from 0.0 (transparent) to 1.0 (opaque)."
    field :border_radius, :float, doc: "Corner radius in pixels."
    field :filter_method, Plushie.Type.FilterMethod, doc: "Image interpolation mode."
    field :expand, :boolean, doc: "Expand image to fill available space."
    field :scale, :float, doc: "Scale factor for the image."
    field :crop, :map, doc: "Crop rectangle: `%{x, y, width, height}` (integer pixel values)."
    field :alt, :string, doc: "Accessible label for the image."
    field :description, :string, doc: "Extended accessible description for the image."
    field :decorative, :boolean, doc: "When true, hides the image from assistive technology."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."

    positional [:source]
  end
end
