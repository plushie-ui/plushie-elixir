defmodule Julep.Event.MouseArea do
  @moduledoc """
  Mouse area widget events (right-click, hover, etc.).

  These events come from `mouse_area` wrapper widgets and cover
  interactions that the standard button click handler does not, such as
  right/middle clicks, hover enter/exit, cursor movement, and scroll.

  ## Fields

    * `type` - `:right_press`, `:right_release`, `:middle_press`,
      `:middle_release`, `:double_click`, `:enter`, `:exit`, `:move`,
      or `:scroll`
    * `id` - the mouse_area node ID
    * `x`, `y` - cursor position (present on move/scroll events)
    * `delta_x`, `delta_y` - scroll deltas (present on scroll events)

  ## Pattern matching

      def update(model, %MouseArea{type: :right_press, id: "canvas"}) do
        open_context_menu(model)
      end

      def update(model, %MouseArea{type: :enter, id: "tooltip-target"}) do
        %{model | tooltip_visible: true}
      end

      def update(model, %MouseArea{type: :move, id: "drag-zone", x: x, y: y}) do
        track_cursor(model, x, y)
      end
  """

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
