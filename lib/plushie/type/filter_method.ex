defmodule Plushie.Type.FilterMethod do
  @moduledoc """
  Interpolation mode for the image `filter_method` prop.

  Maps to iced's `image::FilterMethod` enum.
  """

  use Plushie.Type

  @type t :: :nearest | :linear

  enum([:nearest, :linear])
end
