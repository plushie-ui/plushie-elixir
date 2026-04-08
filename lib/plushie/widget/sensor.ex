defmodule Plushie.Widget.Sensor do
  @moduledoc """
  Sensor, detects visibility and size changes on child content.
  """

  use Plushie.Widget

  # No a11y defaults: layout containers are transparent to AT

  widget :sensor, container: :single do
    field :delay, :integer, doc: "Delay in milliseconds before emitting events."
    field :anticipate, :float, doc: "Distance in pixels to anticipate visibility."
    field :on_resize, :string, doc: "Event tag for resize events."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, doc: "Accessibility annotations."
  end
end
