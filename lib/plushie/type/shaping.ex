defmodule Plushie.Type.Shaping do
  @moduledoc """
  Text shaping strategy for the text `shaping` prop.

  Maps to iced's `text::Shaping` enum.
  """

  use Plushie.Type

  @type t :: :basic | :advanced | :auto

  enum([:basic, :advanced, :auto])
end
