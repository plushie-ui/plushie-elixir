defmodule Plushie.Type.ContentFit do
  @moduledoc """
  Scaling mode for the `content_fit` prop on image and SVG widgets.

  Maps to iced's `ContentFit` enum.
  """

  use Plushie.Type

  @type t :: :contain | :cover | :fill | :none | :scale_down

  enum([:contain, :cover, :fill, :none, :scale_down])
end
