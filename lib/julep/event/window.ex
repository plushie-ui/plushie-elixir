defmodule Julep.Event.Window do
  @moduledoc """
  Window lifecycle events.

  ## Pattern matching

      def update(model, %Window{type: :resized, window_id: "main", width: w, height: h}), do: ...
      def update(model, %Window{type: :close_requested, window_id: wid}), do: ...
  """

  @type event_type ::
          :opened | :closed | :close_requested | :moved | :resized
          | :focused | :unfocused | :rescaled
          | :file_hovered | :file_dropped | :files_hovered_left

  @type t :: %__MODULE__{
          type: event_type(),
          window_id: String.t(),
          x: number() | nil,
          y: number() | nil,
          width: number() | nil,
          height: number() | nil,
          position: {number(), number()} | nil,
          path: String.t() | nil,
          scale_factor: number() | nil
        }

  @enforce_keys [:type, :window_id]
  defstruct [:type, :window_id, :x, :y, :width, :height, :position, :path, :scale_factor]
end
