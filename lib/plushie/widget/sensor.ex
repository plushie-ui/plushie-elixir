defmodule Plushie.Widget.Sensor do
  @moduledoc """
  Sensor, detects visibility and size changes on child content.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :generic_container}

  widget :sensor, container: :single do
    field :delay, :integer, doc: "Delay in milliseconds before emitting events."
    field :anticipate, :float, doc: "Distance in pixels to anticipate visibility."
    field :on_resize, :string, doc: "Event tag for resize events."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end
end
