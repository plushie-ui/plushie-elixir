defmodule Plushie.Event.MouseEvent do
  @moduledoc """
  Global mouse events from subscriptions.

  ## Pattern matching

      def update(model, %MouseEvent{type: :moved, x: x, y: y}), do: ...
      def update(model, %MouseEvent{type: :button_pressed, button: :left, captured: false}), do: ...
  """

  @type event_type ::
          :moved | :entered | :left | :button_pressed | :button_released | :wheel_scrolled

  @type button :: :left | :right | :middle | :back | :forward
  @type scroll_unit :: :line | :pixel

  @type t :: %__MODULE__{
          type: event_type(),
          x: number() | nil,
          y: number() | nil,
          button: button() | nil,
          delta_x: number() | nil,
          delta_y: number() | nil,
          unit: scroll_unit() | nil,
          captured: boolean(),
          window_id: String.t() | nil
        }

  @enforce_keys [:type]
  defstruct [:type, :x, :y, :button, :delta_x, :delta_y, :unit, :window_id, captured: false]
end
