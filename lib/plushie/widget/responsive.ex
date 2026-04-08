defmodule Plushie.Widget.Responsive do
  @moduledoc """
  Responsive layout, adapts to available size by reporting resize events.

  The renderer wraps child content in a sensor that sends
  `%WidgetEvent{type: :resize}` events so the Elixir app can adjust
  its view based on the measured size.
  """

  use Plushie.Widget

  # No a11y defaults: layout containers are transparent to AT

  widget :responsive, container: :single do
    field :width, Plushie.Type.Length, doc: "Container width. Default: fill."
    field :height, Plushie.Type.Length, doc: "Container height. Default: fill."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, doc: "Accessibility annotations."
  end
end
