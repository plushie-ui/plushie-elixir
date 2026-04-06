defmodule Plushie.Type.Style do
  @moduledoc """
  Union type for widget styling: a preset atom or a `StyleMap` struct.

  Preset atoms map to built-in iced theme styles. For per-instance
  customization, use a `Plushie.Type.StyleMap` struct.
  """

  use Plushie.Type

  union do
    enum([
      :default,
      :primary,
      :secondary,
      :success,
      :danger,
      :warning,
      :dark,
      :weak,
      :rounded_box
    ])

    type(Plushie.Type.StyleMap)
  end
end
