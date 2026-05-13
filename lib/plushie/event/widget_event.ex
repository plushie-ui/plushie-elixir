defmodule Plushie.Event.WidgetEvent do
  @moduledoc """
  Events from interactive widgets (buttons, inputs, sliders, etc.).

  Built-in widget event families decode to atoms. Custom widget
  events decode to `{widget_type, event}` tuples, for example
  `{:star_rating, :selected}`.

  The `scope` field contains the ancestor scope chain in reverse order
  (nearest parent first). Use `Plushie.Event.target/1` to reconstruct the
  full forward-order scoped path.

  The `window_id` field identifies which window produced the event. Runtime-
  delivered widget events always include it. This stays separate from `scope`:
  scope is container ancestry inside a window, while `window_id` identifies
  the window itself.

  ## Pattern matching

      def update(model, %WidgetEvent{type: :click, id: "save"}), do: save(model)
      def update(model, %WidgetEvent{type: :input, id: "name", value: val}), do: ...
      def update(model, %WidgetEvent{type: :toggle, id: "dark", value: on?}), do: ...

      # Match on scope for disambiguation
      def update(model, %WidgetEvent{type: :click, id: "save", scope: ["form" | _]}), do: ...
  """

  @type builtin_event_type ::
          :click
          | :input
          | :submit
          | :toggle
          | :select
          | :slide
          | :slide_release
          | :paste
          | :open
          | :close
          | :option_hovered
          | :key_binding
          | :link_click
          | :sort
          | :pane_focus_cycle
          | :press
          | :release
          | :move
          | :scroll
          | :scrolled
          | :enter
          | :exit
          | :double_click
          | :resize
          | :status
          | :focused
          | :blurred
          | :drag
          | :drag_end
          | :key_press
          | :key_release
          | :pane_resized
          | :pane_dragged
          | :pane_clicked
          | :transition_complete

  @type widget_event_type :: {widget_type :: atom(), event_name :: atom()}

  @type event_type :: builtin_event_type() | widget_event_type()

  @typedoc """
  Widget event struct.

  Hand-built test events may leave `window_id` unset. Events decoded from the
  renderer always include it.
  """
  @type t :: %__MODULE__{
          type: event_type(),
          id: String.t(),
          window_id: String.t() | nil,
          scope: [String.t()],
          value: term()
        }

  @typedoc "Widget event delivered by the renderer."
  @type delivered_t :: %__MODULE__{
          type: event_type(),
          id: String.t(),
          window_id: String.t(),
          scope: [String.t()],
          value: term()
        }

  @enforce_keys [:type, :id]
  defstruct [:type, :id, :value, :window_id, scope: []]

  @builtin_event_types ~w(
    click input submit toggle select slide slide_release paste open close option_hovered
    key_binding link_click sort scrolled status pane_focus_cycle
    press release move scroll enter exit double_click resize
    focused blurred drag drag_end key_press key_release
    pane_resized pane_dragged pane_clicked
    transition_complete
  )a

  @doc false
  @spec builtin_event_type?(term()) :: boolean()
  def builtin_event_type?(type) when is_atom(type), do: type in @builtin_event_types
  def builtin_event_type?(_), do: false

  defimpl Inspect do
    def inspect(event, _opts) do
      target = Plushie.Event.target(event)
      parts = [inspect(event.type), " ", inspect(target)]

      parts =
        if event.window_id,
          do: parts ++ [" window=", Kernel.inspect(event.window_id)],
          else: parts

      parts =
        if event.value != nil,
          do: parts ++ [" value=", Kernel.inspect(event.value)],
          else: parts

      IO.iodata_to_binary(["#WidgetEvent<" | parts] ++ [">"])
    end
  end
end
