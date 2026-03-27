defmodule Plushie.Event.MouseAreaEvent do
  @moduledoc """
  Mouse area widget events (right-click, hover, etc.).

  These events come from `mouse_area` wrapper widgets and cover
  interactions that the standard button click handler does not, such as
  right/middle clicks, hover enter/exit, cursor movement, and scroll.

  The `scope` field contains the ancestor scope chain in reverse order
  (nearest parent first). Use `Plushie.Event.target/1` to reconstruct the
  full forward-order scoped path.

  The `window_id` field identifies which window produced the event. Runtime-
  delivered mouse area events always include it.

  ## Fields

    * `type` - `:right_press`, `:right_release`, `:middle_press`,
      `:middle_release`, `:double_click`, `:enter`, `:exit`, `:move`,
      or `:scroll`
    * `id` - the mouse_area node ID
    * `scope` - ancestor scope chain (nearest parent first), default `[]`
    * `x`, `y` - cursor position (present on move/scroll events)
    * `delta_x`, `delta_y` - scroll deltas (present on scroll events)

  ## Pattern matching

      def update(model, %MouseAreaEvent{type: :right_press, id: "canvas"}) do
        open_context_menu(model)
      end

      def update(model, %MouseAreaEvent{type: :enter, id: "tooltip-target"}) do
        %{model | tooltip_visible: true}
      end

      def update(model, %MouseAreaEvent{type: :move, id: "drag-zone", x: x, y: y}) do
        track_cursor(model, x, y)
      end
  """

  @type event_type ::
          :right_press
          | :right_release
          | :middle_press
          | :middle_release
          | :double_click
          | :enter
          | :exit
          | :move
          | :scroll

  @typedoc """
  Mouse area event struct.

  Hand-built test events may leave `window_id` unset. Events decoded from the
  renderer always include it.
  """
  @type t :: %__MODULE__{
          type: event_type(),
          id: String.t(),
          window_id: String.t() | nil,
          scope: [String.t()],
          x: number() | nil,
          y: number() | nil,
          delta_x: number() | nil,
          delta_y: number() | nil
        }

  @typedoc "Mouse area event delivered by the renderer."
  @type delivered_t :: %__MODULE__{
          type: event_type(),
          id: String.t(),
          window_id: String.t(),
          scope: [String.t()],
          x: number() | nil,
          y: number() | nil,
          delta_x: number() | nil,
          delta_y: number() | nil
        }

  @enforce_keys [:type, :id]
  defstruct [:type, :id, :x, :y, :delta_x, :delta_y, :window_id, scope: []]

  defimpl Inspect do
    def inspect(event, _opts) do
      target = Plushie.Event.target(event)

      window =
        if event.window_id, do: " window=#{Kernel.inspect(event.window_id)}", else: ""

      "#MouseAreaEvent<#{Kernel.inspect(event.type)} #{Kernel.inspect(target)}#{window}>"
    end
  end
end
