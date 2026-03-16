defmodule Julep.Event.MouseArea do
  @moduledoc "Mouse area widget events (right-click, hover, etc.)."

  @type event_type ::
          :right_press | :right_release | :middle_press | :middle_release
          | :double_click | :enter | :exit | :move | :scroll

  @type t :: %__MODULE__{
          type: event_type(),
          id: String.t(),
          x: number() | nil,
          y: number() | nil,
          delta_x: number() | nil,
          delta_y: number() | nil
        }

  defstruct [:type, :id, :x, :y, :delta_x, :delta_y]
end
