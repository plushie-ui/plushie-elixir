defmodule Julep.Event.Touch do
  @moduledoc """
  Touch events from subscriptions.

  Emitted for touchscreen interactions. Each finger is tracked by a unique
  `finger_id` across the `:pressed` -> `:moved` -> `:lifted` lifecycle.
  A `:lost` event indicates the OS interrupted tracking (e.g. a system
  gesture took over).

  ## Fields

    * `type` - `:pressed`, `:moved`, `:lifted`, or `:lost`
    * `finger_id` - opaque identifier for the finger
    * `x`, `y` - touch position in logical pixels
    * `captured` - whether a subscription captured this event

  ## Pattern matching

      def update(model, %Touch{type: :pressed, finger_id: fid, x: x, y: y}) do
        start_touch(model, fid, x, y)
      end

      def update(model, %Touch{type: :moved, finger_id: fid, x: x, y: y}) do
        move_touch(model, fid, x, y)
      end

      def update(model, %Touch{type: :lifted, finger_id: fid}) do
        end_touch(model, fid)
      end
  """

  @type t :: %__MODULE__{
          type: :pressed | :moved | :lifted | :lost,
          finger_id: term(),
          x: number(),
          y: number(),
          captured: boolean()
        }

  @enforce_keys [:type, :finger_id, :x, :y]
  defstruct [:type, :finger_id, :x, :y, captured: false]
end
