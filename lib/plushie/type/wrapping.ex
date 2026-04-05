defmodule Plushie.Type.Wrapping do
  @moduledoc """
  Line-break strategy for the text `wrapping` prop.

  Maps to iced's `text::Wrapping` enum.
  """

  use Plushie.Type

  @type t :: :none | :word | :glyph | :word_or_glyph

  enum([:none, :word, :glyph, :word_or_glyph])
end
