defmodule Plushie.Widget.Sensor do
  @moduledoc """
  Sensor, detects visibility and size changes on child content.
  """

  use Plushie.Widget

  widget :sensor, container: :single do
    field :delay, :integer, doc: "Delay in milliseconds before emitting events."
    field :anticipate, :float, doc: "Distance in pixels to anticipate visibility."
    field :on_resize, :string, doc: "Event tag for resize events."
  end
end
