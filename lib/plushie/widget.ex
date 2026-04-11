defmodule Plushie.Widget do
  @moduledoc """
  Macro-based DSL for declaring Plushie widgets.

  Supports two kinds of widget:

  - `:native_widget` -- backed by a Rust crate implementing the
    `PlushieWidget` trait. Requires `rust_crate` and `rust_constructor`
    declarations.
  - `:widget` -- pure Elixir widget. Features are detected at compile
    time based on what callbacks are defined:
    - Has `state` declarations -> stateful (deferred view, state
      persistence via the runtime).
    - No `state` -> stateless (immediate view in `new/2`).
    - Has `handle_event/2` -> participates in event dispatch.
    - Has `subscribe/2` -> widget-scoped subscriptions.

  ## Usage

      defmodule MyApp.Gauge do
        use Plushie.Widget, :native_widget

        widget :gauge

        field :value, :float
        field :min, :float, default: 0
        field :max, :float, default: 100
        field :color, Plushie.Type.Color, default: :blue
        field :width, Plushie.Type.Length
        field :height, Plushie.Type.Length

        rust_crate "native/my_gauge"
        rust_constructor "my_gauge::GaugeWidget::new()"

        event :value_changed, fields: [value: :float]
        command :set_value, value: :float
      end

  ## Generated code

  The macro generates:

  - `type_names/0` -- returns `[:gauge]` (from the `widget` declaration)
  - `native_crate/0` -- returns the `rust_crate` path (native_widget only)
  - `rust_constructor/0` -- returns the Rust expression (native_widget only)
  - `new/2` -- creates a `%Module{}` struct ()
  - Setter functions per field for pipeline composition
  - `with_options/2` -- applies keyword options via setters
  - `build/1` -- converts the struct to a `ui_node()` map
  - `@type t`, `@type option` -- typespecs for dialyzer
  - `Plushie.Widget` protocol implementation
  - `__event_specs__/0`, `__event_spec__/1` -- typed event metadata
  - Command functions (native_widget only) that wrap
    `Plushie.Command.widget_command/3`

  ## Field types

  Field types are resolved via `Plushie.Type.resolve/1`. Primitive
  atom shortcuts (`:integer`, `:float`, `:string`, `:boolean`,
  `:atom`, `:any`, `:map`), `Plushie.Type` module names (e.g.
  `Plushie.Type.Color`), and composite forms (`{:list, :string}`)
  are accepted. Values are stored raw; `Tree.normalize/1` handles
  wire encoding in a single pass.

  ## Composite widgets

  If the using module defines `view/2` (leaf) or `view/3` (container),
  `new/2` delegates to it after resolving props:

      defmodule MyApp.LabeledInput do
        use Plushie.Widget

        widget :labeled_input

        field :label, :string

        def view(id, props) do
          import Plushie.UI
          column id: id do
            text(props.label)
          end
        end
      end

  ### view/2 vs view/3

  Use `view/2` for simple widgets:

      def view(id, props) do
        %{id: id, type: "text", props: %{content: props.label}, children: []}
      end

  Use `view/3` when the widget has state (declared via `state`).
  The third argument is the widget's internal state map:

      def view(id, props, state) do
        fill = if state.hover, do: "#ff0", else: "#ccc"
        ...
      end

  ## Common options

  Widgets that support accessibility or event rate limiting declare
  these as normal fields:

  - `field :a11y, Plushie.Type.A11y, merge: true` -- accessibility
    overrides (see `Plushie.Type.A11y`). The `merge: true` option
    makes the setter merge user values with widget defaults.
  - `field :event_rate, :integer` -- maximum events per second for
    coalescable events from this widget.
  """

  alias Plushie.Widget.DSL.{Codegen, Validation}

  # -- Behaviour callbacks ---------------------------------------------------

  @doc "Node type atoms this widget handles."
  @callback type_names() :: [atom()]

  @doc "Path to the Rust crate relative to the package root."
  @callback native_crate() :: String.t()

  @doc "Full Rust constructor expression for the widget."
  @callback rust_constructor() :: String.t()

  @optional_callbacks [native_crate: 0, rust_constructor: 0]

  # -- Protocol delegation ---------------------------------------------------
  # Delegate common protocol functions so users don't need to reference
  # Plushie.Tree.Node directly.

  @typedoc "A UI tree node map. Every widget builder returns this shape."
  @type ui_node :: Plushie.Tree.Node.ui_node()

  @typedoc "A child element: either an already-resolved node map or a widget struct."
  @type child :: ui_node() | struct()

  @doc "Converts a widget struct to a `ui_node()` map via the Tree.Node protocol."
  @spec to_node(struct()) :: ui_node()
  defdelegate to_node(widget), to: Plushie.Tree.Node

  # -- __using__ -------------------------------------------------------------

  @valid_kinds [:native_widget, :widget]

  defmacro __using__(opts) when is_list(opts) do
    quote do: unquote(__using_kind__(:widget))
  end

  defmacro __using__(kind) when kind not in [:native_widget, :widget] do
    raise ArgumentError,
          "Plushie.Widget kind must be one of #{inspect(@valid_kinds)}, got: #{inspect(kind)}"
  end

  defmacro __using__(kind) when kind in [:native_widget, :widget] do
    __using_kind__(kind)
  end

  defp __using_kind__(kind) do
    common =
      quote do
        @behaviour Plushie.Widget
        @_widget_kind unquote(kind)

        Module.register_attribute(__MODULE__, :_widget_props, accumulate: true)
        Module.register_attribute(__MODULE__, :_widget_commands, accumulate: true)
        Module.register_attribute(__MODULE__, :_widget_event_familys, accumulate: true)
        Module.register_attribute(__MODULE__, :_widget_event_family_specs, accumulate: true)
        Module.put_attribute(__MODULE__, :_widget_type_name, nil)
        Module.put_attribute(__MODULE__, :_widget_container, false)
        Module.put_attribute(__MODULE__, :_widget_positional, nil)
      end

    widget_attrs =
      if kind == :widget do
        quote do
          Module.register_attribute(__MODULE__, :_widget_state_fields, accumulate: true)
          Module.put_attribute(__MODULE__, :_widget_cache_key_fn, nil)
        end
      end

    imports =
      case kind do
        :native_widget ->
          quote do
            import Plushie.Widget.DSL.Macro,
              only: [
                widget: 1,
                widget: 2,
                widget: 3,
                positional: 1,
                event: 1,
                event: 2,
                field: 2,
                field: 3,
                command: 1,
                command: 2,
                rust_crate: 1,
                rust_constructor: 1
              ]

            Module.put_attribute(__MODULE__, :_rust_crate, nil)
            Module.put_attribute(__MODULE__, :_rust_constructor, nil)
          end

        :widget ->
          quote do
            import Plushie.Widget.DSL.Macro,
              only: [
                widget: 1,
                widget: 2,
                widget: 3,
                positional: 1,
                state: 1,
                cache_key: 1,
                event: 1,
                event: 2,
                field: 2,
                field: 3
              ]

            import Plushie.UI
          end
      end

    before_compile =
      quote do
        @before_compile Plushie.Widget
      end

    [common, widget_attrs, imports, before_compile]
  end

  # -- __before_compile__ ----------------------------------------------------

  defmacro __before_compile__(env) do
    kind = Module.get_attribute(env.module, :_widget_kind)
    widget_type = Module.get_attribute(env.module, :_widget_type_name)
    container = Module.get_attribute(env.module, :_widget_container)
    props = Module.get_attribute(env.module, :_widget_props) |> Enum.reverse()
    commands = Module.get_attribute(env.module, :_widget_commands) |> Enum.reverse()
    events = Module.get_attribute(env.module, :_widget_event_familys) |> Enum.reverse()
    event_specs = Module.get_attribute(env.module, :_widget_event_family_specs) |> Enum.reverse()

    Validation.validate_declarations!(env, kind, widget_type, events)
    Validation.validate_prop_types!(env, props)
    Validation.validate_command_types!(commands)
    Validation.warn_duplicate_props(env, props)
    Validation.warn_duplicate_events(env, events)
    Validation.validate_reserved_names!(env, props)

    positional = Module.get_attribute(env.module, :_widget_positional) || []
    Validation.validate_positional!(env, positional, props)

    rust_crate_val = Module.get_attribute(env.module, :_rust_crate)
    rust_constructor_val = Module.get_attribute(env.module, :_rust_constructor)
    has_view_3 = Module.defines?(env.module, {:view, 3})
    has_view = Module.defines?(env.module, {:view, 2}) or has_view_3

    if has_view do
      Validation.validate_widget_callbacks!(env, has_view_3)
    end

    type_string = Atom.to_string(widget_type)

    behaviour_fns =
      Codegen.generate_behaviour_fns(
        kind,
        widget_type,
        events,
        event_specs,
        rust_crate_val,
        rust_constructor_val
      )

    state_fields_raw =
      (Module.get_attribute(env.module, :_widget_state_fields) || [])
      |> Enum.reverse()

    # Normalize state fields: 2-tuples from keyword form become {name, default},
    # 3-tuples from block form carry a type: {name, default, type}.
    # For the runtime (state defaults map), only name and default matter.
    state_fields =
      Enum.map(state_fields_raw, fn
        {name, default, _type} -> {name, default}
        {name, default} -> {name, default}
      end)

    widget_code =
      if has_view do
        # All widgets with view go through the unified path:
        # struct + placeholder to_node + deferred view.
        prop_validation = Codegen.generate_prop_validation(props)

        Codegen.generate_widget_new(
          env.module,
          widget_type,
          type_string,
          events,
          event_specs,
          props,
          state_fields,
          prop_validation
        )
      else
        # Struct-only widgets (native_widget or builtin, no view callback).
        Codegen.generate_struct_widget(
          env.module,
          kind,
          widget_type,
          container,
          props,
          positional: positional,
          events: events,
          event_specs: event_specs
        )
      end

    # Inject @behaviour WidgetHandler for stateful widgets (detected by state fields).
    # Inject WidgetHandler behaviour for all widgets with view callbacks.
    # This must happen in __before_compile__ since we detect view at this point.
    widget_handler_behaviour =
      if has_view do
        quote do
          @behaviour Plushie.Widget.Handler
        end
      end

    command_fns = Codegen.generate_commands(commands)
    prop_names_fn = Codegen.generate_prop_names(props)
    dsl_macro = Codegen.generate_dsl_macro(widget_type, props)

    cache_key_fn =
      if kind == :widget do
        Codegen.generate_cache_key_fn(Module.get_attribute(env.module, :_widget_cache_key_fn))
      end

    widget_info_fn =
      Codegen.generate_widget_info(kind, type_string, props, events, state_fields, commands)

    moduledoc_update =
      Codegen.generate_moduledoc_update(
        env,
        props,
        positional,
        events,
        event_specs,
        state_fields_raw,
        commands
      )

    quote do
      unquote(widget_handler_behaviour)
      unquote(behaviour_fns)
      unquote(widget_code)
      unquote(command_fns)
      unquote(cache_key_fn)
      unquote(prop_names_fn)
      unquote(dsl_macro)
      unquote(widget_info_fn)
      unquote(moduledoc_update)
    end
  end
end
