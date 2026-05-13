defmodule Plushie.Type.TextDirection do
  @moduledoc """
  Text direction hint for text and input widgets.
  """

  use Plushie.Type

  @type t :: :auto | :ltr | :rtl

  enum([:auto, :ltr, :rtl])
end
