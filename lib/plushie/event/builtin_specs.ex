defmodule Plushie.Event.BuiltinSpecs do
  @moduledoc """
  Canonical event specs for all built-in widget event types.

  Each spec describes what data the event carries and where it goes:

  - `%{carrier: :none}` -- no payload (just id/scope)
  - `%{carrier: :value, type: type}` -- scalar in `WidgetEvent.value`
  - `%{carrier: :data, fields: [field: type]}` -- map in `WidgetEvent.data`

  Type identifiers are either built-in atoms (`:number`, `:string`,
  `:boolean`, `:any`) or modules implementing `Plushie.Event.EventType`.

  Used by the canvas widget emit path and the protocol decoder to route
  event data into the correct WidgetEvent fields with proper parsing.
  """

  @typedoc """
  Event field type identifier.

  Built-in atomic types or a module implementing `Plushie.Event.EventType`.
  """
  @type field_type :: :number | :string | :boolean | :any | module()

  @typedoc """
  Event spec describing the payload shape.

  - `:none` -- no payload
  - `:value` -- scalar value, stored in `WidgetEvent.value`
  - `:data` -- structured map, stored in `WidgetEvent.data` with atom keys
  """
  @type t ::
          %{carrier: :none}
          | %{carrier: :value, type: field_type()}
          | %{carrier: :data, fields: [{atom(), field_type()}]}

  @specs %{
    # -- Standard widget events --
    click: %{carrier: :none},
    input: %{carrier: :value, type: :string},
    submit: %{carrier: :value, type: :string},
    toggle: %{carrier: :value, type: :boolean},
    select: %{carrier: :value, type: :any},
    slide: %{carrier: :value, type: :number},
    slide_release: %{carrier: :value, type: :number},
    paste: %{carrier: :value, type: :string},
    open: %{carrier: :none},
    close: %{carrier: :none},
    option_hovered: %{carrier: :value, type: :any},
    key_binding: %{carrier: :data, fields: []},
    sort: %{carrier: :data, fields: [column: :string]},
    scroll: %{
      carrier: :data,
      fields: [
        absolute_x: :number,
        absolute_y: :number,
        relative_x: :number,
        relative_y: :number
      ]
    },
    pane_focus_cycle: %{carrier: :none},

    # -- Canvas element events --
    # Events targeting specific interactive elements inside a canvas widget.
    canvas_element_enter: %{carrier: :none},
    canvas_element_leave: %{carrier: :none},
    canvas_element_click: %{carrier: :none},
    canvas_element_key_press: %{
      carrier: :data,
      fields: [
        key: Plushie.Type.Key,
        modifiers: Plushie.Type.KeyModifiers,
        text: :string
      ]
    },
    canvas_element_key_release: %{
      carrier: :data,
      fields: [
        key: Plushie.Type.Key,
        modifiers: Plushie.Type.KeyModifiers
      ]
    },
    canvas_element_drag: %{
      carrier: :data,
      fields: [x: :number, y: :number, dx: :number, dy: :number]
    },
    canvas_element_drag_end: %{carrier: :none},
    canvas_element_focused: %{carrier: :none},
    canvas_element_blurred: %{carrier: :none},

    # -- Canvas-level events --
    canvas_focused: %{carrier: :none},
    canvas_blurred: %{carrier: :none},
    canvas_group_focused: %{carrier: :none},
    canvas_group_blurred: %{carrier: :none}
  }

  @canvas_internal_types MapSet.new([
                           :canvas_element_enter,
                           :canvas_element_leave,
                           :canvas_element_click,
                           :canvas_element_key_press,
                           :canvas_element_key_release,
                           :canvas_element_drag,
                           :canvas_element_drag_end,
                           :canvas_element_focused,
                           :canvas_element_blurred,
                           :canvas_focused,
                           :canvas_blurred,
                           :canvas_group_focused,
                           :canvas_group_blurred
                         ])

  @doc "Returns the event spec for a built-in event type, or nil."
  @spec spec(name :: atom()) :: t() | nil
  def spec(name) when is_atom(name), do: Map.get(@specs, name)

  @doc "Returns true if the event type is a canvas-internal type."
  @spec canvas_internal?(type :: atom()) :: boolean()
  def canvas_internal?(type) when is_atom(type), do: MapSet.member?(@canvas_internal_types, type)
  def canvas_internal?(_), do: false

  @doc "Returns all built-in event specs as a map."
  @spec all() :: %{atom() => t()}
  def all, do: @specs
end
