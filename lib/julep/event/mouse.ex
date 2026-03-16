defmodule Julep.Event.Mouse do
  @moduledoc """
  Global mouse events from subscriptions.

  ## Pattern matching

      def update(model, %Mouse{type: :moved, x: x, y: y}), do: ...
      def update(model, %Mouse{type: :button_pressed, button: "left", captured: false}), do: ...
  """

  @type event_type ::
          :moved | :entered | :left | :button_pressed | :button_released | :wheel_scrolled

  @type t :: %__MODULE__{
          type: event_type(),
          x: number() | nil,
          y: number() | nil,
          button: String.t() | nil,
          delta_x: number() | nil,
          delta_y: number() | nil,
          unit: String.t() | nil,
          captured: boolean()
        }

  defstruct [:type, :x, :y, :button, :delta_x, :delta_y, :unit, captured: false]
end
