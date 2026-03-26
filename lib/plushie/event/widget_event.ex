defmodule Plushie.Event.WidgetEvent do
  @moduledoc """
  Events from interactive widgets (buttons, inputs, sliders, etc.).

  Built-in widget event families decode to atoms. Custom widget extension
  events decode to `{widget_type, event}` tuples, for example
  `{:star_rating, :selected}`.

  The `scope` field contains the ancestor scope chain in reverse order
  (nearest parent first). Use `Plushie.Event.target/1` to reconstruct the
  full forward-order scoped path.

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
          | :sort
          | :scroll
          | :pane_focus_cycle
          | :canvas_element_enter
          | :canvas_element_leave
          | :canvas_element_click
          | :canvas_element_key_press
          | :canvas_element_key_release
          | :canvas_element_drag
          | :canvas_element_drag_end
          | :canvas_element_focused
          | :canvas_element_blurred
          | :canvas_focused
          | :canvas_blurred
          | :canvas_group_focused
          | :canvas_group_blurred

  @type extension_event_type :: {widget_type :: atom(), event_name :: atom()}

  @type event_type :: builtin_event_type() | extension_event_type()

  @type t :: %__MODULE__{
          type: event_type(),
          id: String.t(),
          scope: [String.t()],
          value: term(),
          data: map() | nil
        }

  @enforce_keys [:type, :id]
  defstruct [:type, :id, :value, :data, scope: []]

  @builtin_event_types ~w(
    click input submit toggle select slide slide_release paste open close option_hovered
    key_binding sort scroll pane_focus_cycle canvas_element_enter canvas_element_leave canvas_element_click
    canvas_element_key_press canvas_element_key_release canvas_element_drag
    canvas_element_drag_end canvas_element_focused canvas_element_blurred canvas_focused
    canvas_blurred canvas_group_focused canvas_group_blurred
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
        if event.value != nil,
          do: parts ++ [" value=", Kernel.inspect(event.value)],
          else: parts

      IO.iodata_to_binary(["#WidgetEvent<" | parts] ++ [">"])
    end
  end
end
