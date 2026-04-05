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
          | %{carrier: :data, fields: [{atom(), field_type()}], required: [atom()]}

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
    scrolled: %{
      carrier: :data,
      fields: [
        absolute_x: :number,
        absolute_y: :number,
        relative_x: :number,
        relative_y: :number,
        bounds: :any,
        content_bounds: :any
      ]
    },
    pane_focus_cycle: %{carrier: :data, fields: [pane: :any]},

    # -- Generic element events --
    # Focus, blur, drag, and key events. These apply to any focusable or
    # draggable element (canvas interactive groups, widgets, etc.).
    focused: %{carrier: :none},
    blurred: %{carrier: :none},
    drag: %{
      carrier: :data,
      fields: [x: :number, y: :number, delta_x: :number, delta_y: :number]
    },
    drag_end: %{
      carrier: :data,
      fields: [x: :number, y: :number]
    },
    key_press: %{
      carrier: :data,
      fields: [
        key: Plushie.Type.Key,
        modifiers: Plushie.Type.KeyModifiers,
        text: :string
      ]
    },
    key_release: %{
      carrier: :data,
      fields: [
        key: Plushie.Type.Key,
        modifiers: Plushie.Type.KeyModifiers
      ]
    },

    # -- Unified pointer events --
    # Replace canvas_*, mouse_*, and sensor_* with a device-agnostic model.
    press: %{
      carrier: :data,
      fields: [
        x: :number,
        y: :number,
        button: Plushie.Type.Pointer,
        pointer: :atom,
        finger: :number,
        modifiers: :any
      ]
    },
    release: %{
      carrier: :data,
      fields: [
        x: :number,
        y: :number,
        button: Plushie.Type.Pointer,
        pointer: :atom,
        finger: :number,
        modifiers: :any
      ]
    },
    move: %{
      carrier: :data,
      fields: [x: :number, y: :number, pointer: :atom, finger: :number, modifiers: :any]
    },
    scroll: %{
      carrier: :data,
      fields: [
        x: :number,
        y: :number,
        delta_x: :number,
        delta_y: :number,
        pointer: :atom,
        modifiers: :any
      ]
    },
    enter: %{carrier: :none},
    exit: %{carrier: :none},
    double_click: %{
      carrier: :data,
      fields: [x: :number, y: :number, pointer: :atom, modifiers: :any]
    },
    resize: %{carrier: :data, fields: [width: :number, height: :number]},

    # -- Pane grid events --
    # Previously PaneEvent structs.
    pane_resized: %{carrier: :data, fields: [split: :any, ratio: :number]},
    pane_dragged: %{
      carrier: :data,
      fields: [
        pane: :any,
        target: :any,
        action: :any,
        region: :any,
        edge: :any
      ]
    },
    pane_clicked: %{carrier: :data, fields: [pane: :any]},

    # -- Animation events --
    transition_complete: %{carrier: :data, fields: [tag: :any, prop: :string]}
  }

  @doc "Returns the event spec for a built-in event type, or nil."
  @spec spec(name :: atom()) :: t() | nil
  def spec(name) when is_atom(name), do: Map.get(@specs, name)

  @doc "Returns all built-in event specs as a map."
  @spec all() :: %{atom() => t()}
  def all, do: @specs
end
