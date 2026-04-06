defmodule Plushie.Event.BuiltinSpecs do
  @moduledoc """
  Canonical event specs for all built-in widget event types.

  Each spec describes what data the event carries and where it goes:

  - `%{carrier: :none}` -- no payload (just id/scope)
  - `%{carrier: :value, type: type}` -- scalar in `WidgetEvent.value`
  - `%{carrier: :value, fields: [field: type]}` -- map in `WidgetEvent.value`

  Type identifiers are either built-in atoms (`:float`, `:string`,
  `:boolean`, `:any`) or modules with a `parse/1` function.

  Used by the canvas widget emit path and the protocol decoder to route
  event data into the correct WidgetEvent fields with proper parsing.
  """

  @typedoc """
  Event field type identifier.

  Built-in atomic types or a module with a `parse/1` function.
  """
  @type field_type :: :float | :string | :boolean | :any | module()

  @typedoc """
  Event spec describing the payload shape.

  - `:none` -- no payload
  - `:value` -- scalar value, stored in `WidgetEvent.value`
  - `:value` with `:fields` -- structured map, stored in `WidgetEvent.value` with atom keys
  """
  @type t ::
          %{
            required(:carrier) => :none | :value,
            optional(:doc) => String.t(),
            optional(:type) => field_type(),
            optional(:fields) => [{atom(), field_type()}],
            optional(:required) => [atom()]
          }

  @specs %{
    # -- Standard widget events --
    click: %{carrier: :none},
    input: %{carrier: :value, type: :string},
    submit: %{carrier: :value, type: :string},
    toggle: %{carrier: :value, type: :boolean},
    select: %{carrier: :value, type: :any},
    slide: %{carrier: :value, type: :float},
    slide_release: %{carrier: :value, type: :float},
    paste: %{carrier: :value, type: :string},
    open: %{carrier: :none},
    close: %{carrier: :none},
    option_hovered: %{carrier: :value, type: :any},
    key_binding: %{carrier: :value, fields: []},
    sort: %{carrier: :value, fields: [column: :string]},
    scrolled: %{
      carrier: :value,
      fields: [
        absolute_x: :float,
        absolute_y: :float,
        relative_x: :float,
        relative_y: :float,
        bounds: :any,
        content_bounds: :any
      ]
    },
    pane_focus_cycle: %{carrier: :value, fields: [pane: :any]},

    # -- Generic element events --
    # Focus, blur, drag, and key events. These apply to any focusable or
    # draggable element (canvas interactive groups, widgets, etc.).
    focused: %{carrier: :none},
    blurred: %{carrier: :none},
    drag: %{
      carrier: :value,
      fields: [x: :float, y: :float, delta_x: :float, delta_y: :float]
    },
    drag_end: %{
      carrier: :value,
      fields: [x: :float, y: :float]
    },
    key_press: %{
      carrier: :value,
      fields: [
        key: Plushie.Type.Key,
        modifiers: Plushie.Type.KeyModifiers,
        text: :string
      ]
    },
    key_release: %{
      carrier: :value,
      fields: [
        key: Plushie.Type.Key,
        modifiers: Plushie.Type.KeyModifiers
      ]
    },

    # -- Unified pointer events --
    # Replace canvas_*, mouse_*, and sensor_* with a device-agnostic model.
    press: %{
      carrier: :value,
      fields: [
        x: :float,
        y: :float,
        button: Plushie.Type.Pointer,
        pointer: :atom,
        finger: :float,
        modifiers: :any
      ]
    },
    release: %{
      carrier: :value,
      fields: [
        x: :float,
        y: :float,
        button: Plushie.Type.Pointer,
        pointer: :atom,
        finger: :float,
        modifiers: :any
      ]
    },
    move: %{
      carrier: :value,
      fields: [x: :float, y: :float, pointer: :atom, finger: :float, modifiers: :any]
    },
    scroll: %{
      carrier: :value,
      fields: [
        x: :float,
        y: :float,
        delta_x: :float,
        delta_y: :float,
        pointer: :atom,
        modifiers: :any
      ]
    },
    enter: %{carrier: :none},
    exit: %{carrier: :none},
    double_click: %{
      carrier: :value,
      fields: [x: :float, y: :float, pointer: :atom, modifiers: :any]
    },
    resize: %{carrier: :value, fields: [width: :float, height: :float]},

    # -- Pane grid events --
    pane_resized: %{carrier: :value, fields: [split: :any, ratio: :float]},
    pane_dragged: %{
      carrier: :value,
      fields: [
        pane: :any,
        target: :any,
        action: :any,
        region: :any,
        edge: :any
      ]
    },
    pane_clicked: %{carrier: :value, fields: [pane: :any]},

    # -- Animation events --
    transition_complete: %{carrier: :value, fields: [tag: :any, prop: :string]}
  }

  @doc "Returns the event spec for a built-in event type, or nil."
  @spec spec(name :: atom()) :: t() | nil
  def spec(name) when is_atom(name), do: Map.get(@specs, name)

  @doc "Returns all built-in event specs as a map."
  @spec all() :: %{atom() => t()}
  def all, do: @specs
end
