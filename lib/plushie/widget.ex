defmodule Plushie.Widget do
  @moduledoc """
  Macro-based DSL for declaring Plushie widgets.

  Supports two kinds of widget:

  - `:native_widget` -- backed by a Rust crate implementing the
    `WidgetExtension` trait. Requires `rust_crate` and `rust_constructor`
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

        prop :value, :number
        prop :min, :number, default: 0
        prop :max, :number, default: 100
        prop :color, :color, default: :blue
        prop :width, :length
        prop :height, :length

        rust_crate "native/my_gauge"
        rust_constructor "my_gauge::GaugeWidget::new()"

        event :value_changed, data: [value: :number]
        command :set_value, value: :number
      end

  ## Generated code

  The macro generates:

  - `type_names/0` -- returns `[:gauge]` (from the `widget` declaration)
  - `native_crate/0` -- returns the `rust_crate` path (native_widget only)
  - `rust_constructor/0` -- returns the Rust expression (native_widget only)
  - `new/2` -- creates a `%Module{}` struct ()
  - Setter functions per prop for pipeline composition
  - `with_options/2` -- applies keyword options via setters
  - `build/1` -- converts the struct to a `ui_node()` map
  - `@type t`, `@type option` -- typespecs for dialyzer
  - `Plushie.Widget` protocol implementation
  - `__event_specs__/0`, `__event_spec__/1` -- typed event metadata
  - Command functions (native_widget only) that wrap
    `Plushie.Command.widget_command/3`

  ## Prop types

  Supported prop types. Values are stored raw; `Tree.normalize/1`
  handles wire encoding in a single pass.

  - `:number`, `:string`, `:boolean` -- pass through
  - `:color` -- normalized via `Plushie.Type.Color.cast/1` (input casting)
  - `:length` -- pass through (encoded by `Tree.normalize`)
  - `:padding` -- pass through (encoded by `Tree.normalize`)
  - `:alignment` -- pass through (encoded by `Tree.normalize`)
  - `:font` -- pass through
  - `:style` -- pass through (atom or StyleMap)
  - `:atom` -- pass through (encoded by `Tree.normalize`)
  - `:map`, `:any` -- pass through
  - `{:list, _}` -- pass through

  ## Composite widgets

  If the using module defines `view/2` (leaf) or `view/3` (container),
  `new/2` delegates to it after resolving props:

      defmodule MyApp.LabeledInput do
        use Plushie.Widget

        widget :labeled_input

        prop :label, :string

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

  ## Special options

  All widgets automatically support:

  - `:a11y` -- accessibility overrides (see `Plushie.Type.A11y`)
  - `:event_rate` -- maximum events per second for coalescable events
    from this widget (see the event throttling design doc)

  These do not need to be declared via `prop` -- they are always
  available on `new/2`.
  """

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
  # Plushie.Widget.WidgetProtocol directly.

  @typedoc "A UI tree node map. Every widget builder returns this shape."
  @type ui_node :: Plushie.Widget.WidgetProtocol.ui_node()

  @typedoc "A child element: either an already-resolved node map or a widget struct."
  @type child :: ui_node() | struct()

  @doc "Converts a widget struct to a `ui_node()` map via the WidgetProtocol."
  @spec to_node(struct()) :: ui_node()
  defdelegate to_node(widget), to: Plushie.Widget.WidgetProtocol

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
      end

    widget_attrs =
      if kind == :widget do
        quote do
          Module.register_attribute(__MODULE__, :_widget_state_fields, accumulate: true)
        end
      end

    imports =
      case kind do
        :native_widget ->
          quote do
            import Plushie.Widget,
              only: [
                widget: 1,
                widget: 2,
                prop: 2,
                prop: 3,
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
            import Plushie.Widget,
              only: [
                widget: 1,
                widget: 2,
                prop: 2,
                prop: 3,
                state: 1,
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

  # -- DSL macros ------------------------------------------------------------

  @doc "Declares the widget type name. Pass `container: true` for container widgets."
  defmacro widget(type_name, opts \\ []) do
    unless is_atom(type_name) do
      raise CompileError,
        file: __CALLER__.file,
        line: __CALLER__.line,
        description: "widget type name must be an atom, got: #{inspect(type_name)}"
    end

    quote do
      if @_widget_type_name do
        IO.warn(
          "widget type already declared as #{inspect(@_widget_type_name)}, overwriting with #{inspect(unquote(type_name))}"
        )
      end

      @_widget_type_name unquote(type_name)
      @_widget_container unquote(Keyword.get(opts, :container, false))
    end
  end

  @doc "Declares a prop with name, type, and optional default."
  defmacro prop(name, type, opts \\ []) do
    quote do
      @_widget_props {unquote(name), unquote(type), unquote(opts)}
    end
  end

  @doc """
  Declares a typed event emitted by a native or canvas widget.

  Supports three forms:

  ## No payload

      event :cleared

  ## Typed value (goes in `WidgetEvent.value`)

      event :select, value: :number

  ## Structured data (goes in `WidgetEvent.data` with atom keys)

      event :change, data: [hue: :number, saturation: :number]

  ## Block form (Ecto-style)

      event :change do
        field :hue, :number
        field :saturation, :number
        field :modifier, :string, required: false
      end

  All fields are required by default. Use `required: false` to make
  a field optional. Optional fields may be omitted from emitted data
  without raising an error.

  ## Block form (nested data)

      event :change do
        data do
          field :hue, :number
          field :saturation, :number
        end
      end

  `value:` and `data:` are mutually exclusive.

  Type identifiers can be built-in atoms (`:number`, `:string`,
  `:boolean`, `:any`) or modules implementing `Plushie.Event.EventType`.
  """
  defmacro event(name, opts_or_block \\ [])

  defmacro event(name, do: block) do
    caller = __CALLER__
    validate_event_name!(name, caller)
    block = expand_type_aliases_in_ast(block, caller)
    spec = parse_event_block(block, caller)
    validate_event_spec!(name, spec, caller)

    quote bind_quoted: [name: name, spec: Macro.escape(spec)] do
      @_widget_event_familys name
      @_widget_event_family_specs {name, spec}
    end
  end

  defmacro event(name, opts) do
    caller = __CALLER__
    validate_event_name!(name, caller)
    opts = expand_type_aliases(opts, caller)
    spec = parse_event_opts(opts, caller)
    validate_event_spec!(name, spec, caller)

    quote bind_quoted: [name: name, spec: Macro.escape(spec)] do
      @_widget_event_familys name
      @_widget_event_family_specs {name, spec}
    end
  end

  @doc """
  Declares internal state fields for a stateful widget.

  State fields are managed by the runtime, not the app model.
  They persist across renders and are passed to `view/3` and
  `handle_event/2`. Declaring state fields makes the widget
  stateful: the view is deferred to tree normalization and the
  `WidgetHandler` behaviour is injected automatically.

      state hover: nil, drag: :none, animation_progress: 0.0
  """
  defmacro state(fields) when is_list(fields) do
    quote do
      for {name, default} <- unquote(fields) do
        @_widget_state_fields {name, default}
      end
    end
  end

  @doc """
  Declares a typed field inside an `event` do-block.

  Fields are required by default. Use `required: false` to make a field
  optional:

      event :change do
        field :hue, :number
        field :saturation, :number
        field :modifier, :string, required: false
      end

  This macro is only valid inside an `event` do-block. It is consumed
  as AST by the event macro and never actually expanded.
  """
  defmacro field(name, type, opts \\ []) do
    quote do
      raise CompileError,
        description:
          "field #{inspect(unquote(name))}/#{inspect(unquote(type))}/#{inspect(unquote(opts))} " <>
            "can only be used inside an event do-block"
    end
  end

  @doc "Declares a command (native_widget only) with optional typed params."
  defmacro command(name, params \\ []) do
    quote do
      @_widget_commands {unquote(name), unquote(params)}
    end
  end

  @doc "Declares the path to the Rust crate (native_widget only)."
  defmacro rust_crate(path) do
    quote do
      @_rust_crate unquote(path)
    end
  end

  @doc "Declares the Rust constructor expression (native_widget only)."
  defmacro rust_constructor(expr) do
    quote do
      @_rust_constructor unquote(expr)
    end
  end

  # -- __before_compile__ ----------------------------------------------------

  @known_prop_types [
    :number,
    :string,
    :boolean,
    :color,
    :length,
    :padding,
    :alignment,
    :style,
    :font,
    :atom,
    :map,
    :any
  ]

  defmacro __before_compile__(env) do
    kind = Module.get_attribute(env.module, :_widget_kind)
    widget_type = Module.get_attribute(env.module, :_widget_type_name)
    container = Module.get_attribute(env.module, :_widget_container)
    props = Module.get_attribute(env.module, :_widget_props) |> Enum.reverse()
    commands = Module.get_attribute(env.module, :_widget_commands) |> Enum.reverse()
    events = Module.get_attribute(env.module, :_widget_event_familys) |> Enum.reverse()
    event_specs = Module.get_attribute(env.module, :_widget_event_family_specs) |> Enum.reverse()

    validate_declarations!(env, kind, widget_type, events)
    validate_prop_types!(env, props)
    validate_command_types!(commands)
    warn_duplicate_props(env, props)
    warn_duplicate_events(env, events)
    validate_reserved_names!(env, props)

    rust_crate_val = Module.get_attribute(env.module, :_rust_crate)
    rust_constructor_val = Module.get_attribute(env.module, :_rust_constructor)
    has_view_3 = Module.defines?(env.module, {:view, 3})
    has_view = Module.defines?(env.module, {:view, 2}) or has_view_3

    if has_view do
      validate_widget_callbacks!(env)
    end

    type_string = Atom.to_string(widget_type)

    behaviour_fns =
      generate_behaviour_fns(
        kind,
        widget_type,
        events,
        event_specs,
        rust_crate_val,
        rust_constructor_val
      )

    state_fields =
      (Module.get_attribute(env.module, :_widget_state_fields) || [])
      |> Enum.reverse()

    widget_code =
      if has_view do
        # All widgets with view go through the unified path:
        # struct + placeholder to_node + deferred view.
        prop_validation = generate_prop_validation(props)

        generate_widget_new(
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
        # Struct-only widgets (native_widget, no view callback).
        generate_struct_widget(
          env.module,
          widget_type,
          type_string,
          container,
          props,
          events,
          event_specs
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

    command_fns = generate_commands(commands)
    prop_names_fn = generate_prop_names(props)
    dsl_macro = generate_dsl_macro(widget_type, props)

    widget_info_fn =
      generate_widget_info(kind, type_string, props, events, state_fields, commands)

    quote do
      unquote(widget_handler_behaviour)
      unquote(behaviour_fns)
      unquote(widget_code)
      unquote(command_fns)
      unquote(prop_names_fn)
      unquote(dsl_macro)
      unquote(widget_info_fn)
    end
  end

  # -- DSL macro generation ----------------------------------------------------

  @doc false
  def generate_dsl_macro(widget_type, _props) do
    macro_name = widget_type

    quote do
      @doc """
      Creates a `#{inspect(unquote(macro_name))}` widget.

      Shorthand for `new/2`. Import this macro to use the widget name
      directly in view functions:

          import #{inspect(__MODULE__)}, only: [#{unquote(Atom.to_string(macro_name))}: 2]

          #{unquote(Atom.to_string(macro_name))}("my-id", prop: value)
      """
      defmacro unquote(macro_name)(id, opts \\ []) do
        mod = __MODULE__
        quote do: unquote(mod).new(unquote(id), unquote(opts))
      end
    end
  end

  # -- Event spec parsing (called at compile time from macros) ----------------

  # Expand module aliases in keyword option values at compile time.
  @doc false
  def expand_type_aliases(opts, caller) when is_list(opts) do
    Enum.map(opts, fn
      {:value, type} ->
        {:value, maybe_expand_alias(type, caller)}

      {:data, fields} when is_list(fields) ->
        {:data, Enum.map(fields, fn {k, v} -> {k, maybe_expand_alias(v, caller)} end)}

      other ->
        other
    end)
  end

  @doc false
  def expand_type_aliases_in_ast(block, caller) do
    Macro.prewalk(block, fn
      {:field, meta, [name, type]} ->
        {:field, meta, [name, maybe_expand_alias(type, caller)]}

      {:field, meta, [name, type, opts]} ->
        {:field, meta, [name, maybe_expand_alias(type, caller), opts]}

      other ->
        other
    end)
  end

  defp maybe_expand_alias({:__aliases__, _, _} = ast, caller) do
    Macro.expand(ast, caller)
  end

  defp maybe_expand_alias(other, _caller), do: other

  @doc false
  def validate_event_name!(name, caller) do
    unless is_atom(name) do
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description: "event name must be an atom, got: #{inspect(name)}"
    end
  end

  @doc false
  def parse_event_opts([], _caller), do: %{carrier: :none}

  def parse_event_opts(opts, caller) when is_list(opts) do
    has_value = Keyword.has_key?(opts, :value)
    has_data = Keyword.has_key?(opts, :data)

    if has_value and has_data do
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description: "event cannot declare both value: and data: -- they are mutually exclusive"
    end

    cond do
      has_value ->
        %{carrier: :value, type: Keyword.fetch!(opts, :value)}

      has_data ->
        fields = Keyword.fetch!(opts, :data)

        unless is_list(fields) and Keyword.keyword?(fields) do
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "event data: must be a keyword list of [field: type], got: #{inspect(fields)}"
        end

        %{carrier: :data, fields: fields, required: Keyword.keys(fields)}

      true ->
        raise CompileError,
          file: caller.file,
          line: caller.line,
          description: "event options must include value: or data:, got: #{inspect(opts)}"
    end
  end

  @doc false
  @spec parse_event_block(block :: Macro.t(), caller :: Macro.Env.t()) ::
          Plushie.Event.BuiltinSpecs.t()
  def parse_event_block(block, caller) do
    stmts = block_to_list(block)

    # Check if the block contains top-level field declarations.
    # If so, treat them as data fields directly (no wrapping `data do end`).
    has_top_level_fields =
      Enum.any?(stmts, fn
        {:field, _meta, [_name, _type | _rest]} -> true
        _ -> false
      end)

    if has_top_level_fields do
      parse_data_block_to_spec(stmts, caller)
    else
      Enum.reduce(stmts, %{carrier: :none}, fn
        {:value, _meta, [type]}, %{carrier: :none} ->
          %{carrier: :value, type: type}

        {:data, _meta, [[do: inner_block]]}, %{carrier: :none} ->
          parse_data_block_to_spec(block_to_list(inner_block), caller)

        {:data, _meta, [fields]}, %{carrier: :none} when is_list(fields) ->
          unless Keyword.keyword?(fields) do
            raise CompileError,
              file: caller.file,
              line: caller.line,
              description: "event data: must be a keyword list of [field: type]"
          end

          %{carrier: :data, fields: fields, required: Keyword.keys(fields)}

        _other, acc ->
          acc
      end)
    end
  end

  # Parses a list of `field` statements into a data spec with required tracking.
  defp parse_data_block_to_spec(stmts, caller) do
    {fields, required} = parse_data_stmts(stmts, caller)
    %{carrier: :data, fields: fields, required: required}
  end

  defp block_to_list({:__block__, _, stmts}), do: stmts
  defp block_to_list(stmt), do: [stmt]

  defp parse_data_stmts(stmts, caller) do
    parsed =
      Enum.map(stmts, fn
        {:field, _meta, [name, type]} when is_atom(name) ->
          {name, type, true}

        {:field, _meta, [name, type, opts]} when is_atom(name) and is_list(opts) ->
          required = Keyword.get(opts, :required, true)
          {name, type, required}

        other ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "expected `field :name, :type` inside data block, got: #{Macro.to_string(other)}"
      end)

    fields = Enum.map(parsed, fn {name, type, _req} -> {name, type} end)

    required =
      parsed
      |> Enum.filter(fn {_name, _type, req} -> req end)
      |> Enum.map(fn {name, _type, _req} -> name end)

    {fields, required}
  end

  @doc false
  @spec validate_event_spec!(
          name :: atom(),
          spec :: Plushie.Event.BuiltinSpecs.t(),
          caller :: Macro.Env.t()
        ) :: :ok
  def validate_event_spec!(name, spec, caller) do
    case spec do
      %{carrier: :value, type: type} ->
        validate_event_field_type!(name, nil, type, caller)

      %{carrier: :data, fields: fields} ->
        Enum.each(fields, fn {field_name, type} ->
          validate_event_field_type!(name, field_name, type, caller)
        end)

      %{carrier: :none} ->
        :ok
    end
  end

  defp validate_event_field_type!(event_name, field_name, type, caller) do
    unless Plushie.Event.EventType.valid_type?(type) do
      context =
        if field_name,
          do: "field #{inspect(field_name)} has",
          else: "has"

      raise CompileError,
        file: caller.file,
        line: caller.line,
        description:
          "event #{inspect(event_name)} #{context} invalid type #{inspect(type)}. " <>
            "Use a built-in type (:number, :string, :boolean, :any) or a module implementing Plushie.Event.EventType."
    end
  end

  defp validate_declarations!(env, kind, widget_type, _events) do
    unless widget_type do
      raise CompileError,
        file: env.file,
        line: 0,
        description: "missing `widget :type_name` declaration in #{inspect(env.module)}"
    end

    if kind == :native_widget do
      unless Module.get_attribute(env.module, :_rust_crate) do
        raise CompileError,
          file: env.file,
          line: 0,
          description: "missing `rust_crate \"path\"` in #{inspect(env.module)}"
      end

      unless Module.get_attribute(env.module, :_rust_constructor) do
        raise CompileError,
          file: env.file,
          line: 0,
          description: "missing `rust_constructor \"expr\"` in #{inspect(env.module)}"
      end
    end

    # All widget kinds can declare events via the event macro.
  end

  defp validate_prop_types!(env, props) do
    for {name, type, _opts} <- props do
      unless valid_type?(type) do
        raise CompileError,
          file: env.file,
          line: 0,
          description:
            "unsupported prop type #{inspect(type)} for prop #{inspect(name)} in #{inspect(env.module)}. " <>
              "Supported: #{inspect(@known_prop_types ++ [{:list, :type}])}"
      end
    end
  end

  defp validate_command_types!(commands) do
    for {cmd_name, params} <- commands, {param_name, type} <- params do
      unless valid_type?(type) do
        raise CompileError,
          description:
            "unsupported command param type #{inspect(type)} for param #{inspect(param_name)} in command #{inspect(cmd_name)}"
      end
    end
  end

  defp warn_duplicate_props(env, props) do
    prop_names = Enum.map(props, fn {name, _, _} -> name end)
    dupes = prop_names -- Enum.uniq(prop_names)

    if dupes != [] do
      IO.warn(
        "duplicate prop names in #{inspect(env.module)}: #{inspect(Enum.uniq(dupes))}",
        Macro.Env.stacktrace(env)
      )
    end
  end

  defp warn_duplicate_events(env, events) do
    dupes = events -- Enum.uniq(events)

    if dupes != [] do
      IO.warn(
        "duplicate event names in #{inspect(env.module)}: #{inspect(Enum.uniq(dupes))}",
        Macro.Env.stacktrace(env)
      )
    end
  end

  @reserved_prop_names [:id, :type, :children, :a11y, :event_rate, :do]

  defp validate_reserved_names!(env, props) do
    for {name, _type, _opts} <- props, name in @reserved_prop_names do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "prop name #{inspect(name)} is reserved in #{inspect(env.module)}. " <>
            "Reserved names: #{inspect(@reserved_prop_names)}"
    end
  end

  defp validate_widget_callbacks!(env) do
    has_view_2 = Module.defines?(env.module, {:view, 2})
    has_view_3 = Module.defines?(env.module, {:view, 3})

    unless has_view_2 or has_view_3 do
      raise CompileError,
        file: env.file,
        line: 0,
        description: "#{inspect(env.module)} must define view/2 or view/3."
    end
  end

  defp generate_widget_new(
         module,
         widget_type,
         _type_string,
         events,
         event_specs,
         props,
         state_fields,
         prop_extract
       ) do
    prop_struct_fields =
      for {name, _type, opts} <- props do
        default = Keyword.get(opts, :default)
        {name, default}
      end

    # Struct fields: :id + declared props + standard widget options
    struct_fields = [{:id, nil} | prop_struct_fields] ++ [{:event_rate, nil}, {:a11y, nil}]

    state_defaults = Macro.escape(Map.new(state_fields))

    has_handle_event = Module.defines?(module, {:handle_event, 2})
    has_view_3 = Module.defines?(module, {:view, 3})
    has_view_2 = Module.defines?(module, {:view, 2})
    participates_in_dispatch = participates_in_dispatch?(has_handle_event, events, state_fields)

    default_handle_event =
      unless has_handle_event do
        # Widgets with event declarations are opaque by default (consume all
        # events). Render-only widgets without events are transparent (events
        # pass through to the app's update/2).
        default_action = if events != [], do: :consumed, else: :ignored

        quote do
          @doc false
          def handle_event(_event, _state), do: unquote(default_action)
        end
      end

    # Composites with view/2 need a view/3 wrapper so the unified
    # normalization path can call view(id, props, state) uniformly.
    view_adapter =
      if has_view_2 and not has_view_3 do
        quote do
          @doc false
          def view(id, props, _state), do: view(id, props)
        end
      end

    quote do
      unquote(view_adapter)

      @doc "Returns the initial internal state for this widget."
      @spec __initial_state__() :: map()
      def __initial_state__, do: unquote(state_defaults)

      @doc "Returns true for widget modules with view callbacks."
      @spec __widget__?() :: true
      def __widget__?, do: true

      unquote(default_handle_event)

      defstruct unquote(Macro.escape(struct_fields))

      defimpl Plushie.Widget.WidgetProtocol do
        @doc """
        Converts the stateful widget struct to a placeholder node.

        The placeholder carries the module and props as metadata tags.
        During tree normalization, the runtime detects these tags and
        renders the widget with the appropriate internal state (stored
        from a previous cycle, or initial defaults for new widgets).
        """
        def to_node(widget) do
          props =
            widget
            |> Map.from_struct()
            |> Map.delete(:id)
            |> Enum.reject(fn {_k, v} -> is_nil(v) end)
            |> Map.new()

          %{
            id: widget.id,
            type: "widget_placeholder",
            props: %{
              __widget__: %Plushie.Widget.Meta.Composite{
                module: unquote(module),
                props: props,
                type: unquote(widget_type),
                events: unquote(events),
                event_specs: unquote(Macro.escape(event_specs)),
                handles_events: unquote(participates_in_dispatch)
              }
            },
            children: []
          }
        end
      end

      @doc """
      Creates a new canvas widget instance.

      Returns a struct that participates in the standard Widget protocol
      pipeline: struct → to_node → normalize. The widget is rendered
      during tree normalization with stored internal state (or initial
      defaults on first render).
      """
      @spec new(id :: String.t(), opts :: keyword()) :: %__MODULE__{}
      def new(id, opts \\ []) when is_binary(id) do
        {event_rate_val, opts} = Keyword.pop(opts, :event_rate)
        {a11y_val, opts} = Keyword.pop(opts, :a11y)

        prop_defaults = unquote(Macro.escape(prop_struct_fields))
        unquote(prop_extract)

        props_map =
          prop_defaults
          |> Enum.map(fn {name, default} ->
            {name, Keyword.get(opts, name, default)}
          end)
          |> Enum.reject(fn {_name, val} -> is_nil(val) end)
          |> Map.new()

        props_map =
          if event_rate_val,
            do: Map.put(props_map, :event_rate, event_rate_val),
            else: props_map

        props_map =
          if a11y_val, do: Map.put(props_map, :a11y, a11y_val), else: props_map

        struct!(__MODULE__, Map.put(props_map, :id, id))
      end
    end
  end

  # Widget participates in event dispatch if it declares events,
  # has state fields, or defines handle_event/2 explicitly.
  defp participates_in_dispatch?(has_handle_event, events, state_fields) do
    has_handle_event or events != [] or state_fields != []
  end

  defp valid_type?(type) when type in @known_prop_types, do: true
  defp valid_type?({:list, inner}) when inner in @known_prop_types, do: true
  defp valid_type?(_), do: false

  # -- Code generation helpers (called at compile time) ----------------------

  @doc false
  def generate_behaviour_fns(
        kind,
        widget_type,
        events,
        event_specs,
        rust_crate_val,
        rust_constructor_val
      ) do
    # Build a map of event_name => spec for __event_spec__/1 lookups.
    specs_map = Map.new(event_specs, fn {name, spec} -> {name, spec} end)

    base =
      quote do
        @impl Plushie.Widget
        def type_names, do: [unquote(widget_type)]

        @doc false
        @spec __widget_type__() :: atom()
        def __widget_type__, do: unquote(widget_type)

        @doc false
        @spec __events__() :: [atom()]
        def __events__, do: unquote(events)

        @doc false
        @spec __event_specs__() :: [{atom(), Plushie.Event.BuiltinSpecs.t()}]
        def __event_specs__, do: unquote(Macro.escape(event_specs))

        @doc false
        @spec __event_spec__(name :: atom()) :: Plushie.Event.BuiltinSpecs.t() | nil
        def __event_spec__(name), do: Map.get(unquote(Macro.escape(specs_map)), name)
      end

    if kind == :native_widget do
      quote do
        unquote(base)

        @impl Plushie.Widget
        def native_crate, do: unquote(rust_crate_val)

        @impl Plushie.Widget
        def rust_constructor, do: unquote(rust_constructor_val)
      end
    else
      base
    end
  end

  @doc false
  def generate_widget_info(kind, type_string, props, events, state_fields, commands) do
    prop_names = Enum.map(props, fn {name, _type, _opts} -> name end)
    event_names = events
    state_field_names = Enum.map(state_fields, fn {name, _default} -> name end)
    command_names = Enum.map(commands, fn {name, _params} -> name end)

    quote do
      @doc false
      @spec __widget_info__() :: map()
      def __widget_info__ do
        %{
          kind: unquote(kind),
          type: unquote(type_string),
          props: unquote(prop_names),
          events: unquote(event_names),
          state_fields: unquote(state_field_names),
          commands: unquote(command_names)
        }
      end
    end
  end

  @doc false
  def generate_prop_names(props) do
    known =
      Enum.map(props, fn {name, _type, _opts} -> name end)
      |> Kernel.++([:event_rate, :a11y])

    quote do
      @doc false
      def __prop_names__, do: unquote(known)
    end
  end

  @known_type_mappings %{
    a11y: Plushie.Type.A11y,
    padding: Plushie.Type.Padding,
    style: Plushie.Type.StyleMap,
    border: Plushie.Type.Border,
    shadow: Plushie.Type.Shadow,
    font: Plushie.Type.Font
  }

  @doc false
  def generate_struct_widget(
        module,
        widget_type,
        type_string,
        container,
        props,
        events,
        event_specs \\ []
      ) do
    struct_def = generate_struct_and_types(props, container)
    new_fn = generate_struct_new(container)
    with_options_fn = generate_with_options(props)
    setters = generate_setters(props)
    dsl_fns = generate_dsl_buildable(props)
    build_fn = generate_build()

    protocol_impl =
      generate_widget_protocol(
        module,
        widget_type,
        type_string,
        container,
        props,
        events,
        event_specs
      )

    quote do
      unquote(struct_def)
      unquote(new_fn)
      unquote(with_options_fn)
      unquote_splicing(setters)
      unquote(dsl_fns)
      unquote(build_fn)
      unquote(protocol_impl)
    end
  end

  # -- Struct-based widget generation -----------------------------------------
  #
  # For struct-only widgets (native_widget) (no view/2 or view/3), we generate:
  # - defstruct with all props + :id + :event_rate + :a11y
  # - @type t with proper field types
  # - @type option union of keyword tuples
  # - new/2 that creates a struct and applies keyword options
  # - with_options/2 that reduces options through setter functions
  # - A setter function per prop with encoding and guards
  # - a11y/2 setter for accessibility overrides
  # - build/1 convenience that calls the protocol
  # - Plushie.Widget protocol implementation (to_node)

  defp generate_struct_and_types(props, container) do
    prop_fields =
      Enum.map(props, fn {name, _type, opts} -> {name, Keyword.get(opts, :default)} end)

    struct_fields =
      [{:id, nil} | prop_fields] ++
        if(container, do: [{:children, []}], else: []) ++
        [{:event_rate, nil}, {:a11y, nil}]

    prop_type_fields = Enum.map(props, &prop_type_ast/1)

    type_fields =
      [{:id, quote(do: String.t())} | prop_type_fields] ++
        if(container,
          do: [{:children, quote(do: [Plushie.Widget.ui_node()])}],
          else: []
        ) ++
        [
          {:event_rate, quote(do: non_neg_integer() | nil)},
          {:a11y, quote(do: Plushie.Type.A11y.t() | nil)}
        ]

    option_variants =
      Enum.map(props, fn {name, type, _opts} ->
        quote(do: {unquote(name), unquote(elixir_type_for(type))})
      end) ++
        [
          quote(do: {:event_rate, non_neg_integer()}),
          quote(do: {:a11y, Plushie.Type.A11y.t()})
        ]

    quote do
      @enforce_keys [:id]
      defstruct unquote(struct_fields)

      @type t :: %__MODULE__{unquote_splicing(type_fields)}

      @type option :: unquote(union_type(option_variants))
    end
  end

  defp prop_type_ast({name, :color, _opts}) do
    {name, quote(do: Plushie.Type.Color.t() | nil)}
  end

  defp prop_type_ast({name, type, _opts}) do
    {name, quote(do: unquote(elixir_type_for(type)) | nil)}
  end

  defp elixir_type_for(:number), do: quote(do: number())
  defp elixir_type_for(:string), do: quote(do: String.t())
  defp elixir_type_for(:boolean), do: quote(do: boolean())
  defp elixir_type_for(:color), do: quote(do: Plushie.Type.Color.input())
  defp elixir_type_for(:length), do: quote(do: Plushie.Type.Length.t())
  defp elixir_type_for(:padding), do: quote(do: Plushie.Type.Padding.t())
  defp elixir_type_for(:alignment), do: quote(do: Plushie.Type.Alignment.t())
  defp elixir_type_for(:font), do: quote(do: Plushie.Type.Font.t())
  defp elixir_type_for(:style), do: quote(do: atom() | Plushie.Type.StyleMap.t())
  defp elixir_type_for(:atom), do: quote(do: atom())
  defp elixir_type_for(:map), do: quote(do: map())
  defp elixir_type_for(:any), do: quote(do: term())
  defp elixir_type_for({:list, inner}), do: quote(do: [unquote(elixir_type_for(inner))])

  defp union_type([single]), do: single

  defp union_type([head | tail]) do
    Enum.reduce(tail, head, fn variant, acc ->
      quote(do: unquote(acc) | unquote(variant))
    end)
  end

  defp generate_struct_new(container) do
    if container do
      quote do
        @doc "Creates a new widget struct with the given ID and keyword options."
        @spec new(id :: String.t(), opts :: [option()]) :: t()
        def new(id, opts \\ []) when is_binary(id) do
          {children, opts} = Keyword.pop(opts, :do, [])
          widget = %__MODULE__{id: id} |> with_options(opts)
          %{widget | children: List.wrap(children)}
        end
      end
    else
      quote do
        @doc "Creates a new widget struct with the given ID and keyword options."
        @spec new(id :: String.t(), opts :: [option()]) :: t()
        def new(id, opts \\ []) when is_binary(id) do
          %__MODULE__{id: id} |> with_options(opts)
        end
      end
    end
  end

  defp generate_with_options(props) do
    v = Macro.var(:v, __MODULE__)
    acc = Macro.var(:acc, __MODULE__)
    key = Macro.var(:key, __MODULE__)

    prop_clauses =
      Enum.map(props, fn {name, _type, _opts} ->
        {:->, [],
         [
           [{:{}, [], [name, v]}, acc],
           quote(do: __MODULE__.unquote(name)(unquote(acc), unquote(v)))
         ]}
      end)

    event_rate_clause =
      {:->, [],
       [
         [{:{}, [], [:event_rate, v]}, acc],
         quote(do: __MODULE__.event_rate(unquote(acc), unquote(v)))
       ]}

    a11y_clause =
      {:->, [],
       [
         [{:{}, [], [:a11y, v]}, acc],
         quote(do: __MODULE__.a11y(unquote(acc), unquote(v)))
       ]}

    unknown_v = Macro.var(:_, __MODULE__)
    unknown_acc = Macro.var(:_, __MODULE__)

    unknown_clause =
      {:->, [],
       [
         [{:{}, [], [key, unknown_v]}, unknown_acc],
         quote do
           raise ArgumentError,
                 "unknown option #{inspect(unquote(key))} for #{inspect(__MODULE__)}.new"
         end
       ]}

    all_clauses = prop_clauses ++ [event_rate_clause, a11y_clause, unknown_clause]
    reducer_fn = {:fn, [], all_clauses}

    quote do
      @doc "Applies keyword options to an existing widget struct."
      @spec with_options(widget :: t(), opts :: [option()]) :: t()
      def with_options(%__MODULE__{} = widget, []), do: widget

      def with_options(%__MODULE__{} = widget, opts) do
        Enum.reduce(opts, widget, unquote(reducer_fn))
      end
    end
  end

  defp generate_dsl_buildable(props) do
    prop_names = Enum.map(props, fn {name, _type, _opts} -> name end)

    field_types_map =
      for {name, _type, _opts} <- props,
          mod = Map.get(@known_type_mappings, name),
          into: %{},
          do: {name, mod}

    quote do
      @behaviour Plushie.DSL.Buildable

      @impl Plushie.DSL.Buildable
      def from_opts(opts), do: with_options(%__MODULE__{id: Keyword.fetch!(opts, :id)}, opts)

      @impl Plushie.DSL.Buildable
      def __field_keys__, do: unquote(prop_names)

      @impl Plushie.DSL.Buildable
      def __field_types__, do: unquote(Macro.escape(field_types_map))

      def __option_keys__, do: unquote(prop_names)
      def __option_types__, do: unquote(Macro.escape(field_types_map))
    end
  end

  defp generate_setters(props) do
    prop_setters =
      Enum.map(props, fn {name, type, opts} ->
        doc = Keyword.get(opts, :doc, "Sets the `#{name}` prop.")
        encoder = encoder_for_type(type)
        value_type = elixir_type_for(type)

        case setter_guard(type) do
          nil ->
            quote do
              @doc unquote(doc)
              @spec unquote(name)(widget :: t(), value :: unquote(value_type)) :: t()
              def unquote(name)(%__MODULE__{} = widget, value) do
                %{widget | unquote(name) => unquote(encoder).(value)}
              end
            end

          guard ->
            quote do
              @doc unquote(doc)
              @spec unquote(name)(widget :: t(), value :: unquote(value_type)) :: t()
              def unquote(name)(%__MODULE__{} = widget, value) when unquote(guard) do
                %{widget | unquote(name) => unquote(encoder).(value)}
              end
            end
        end
      end)

    event_rate_setter =
      quote do
        @doc """
        Sets the maximum event rate (events per second) for this widget's coalescable events.

        Three states: `nil` (no limiting, the default), `0` (track only,
        never emit events to the host), or `N > 0` (emit at most N
        events per second).
        """
        @spec event_rate(widget :: t(), rate :: non_neg_integer()) :: t()
        def event_rate(%__MODULE__{} = widget, rate)
            when is_integer(rate) and rate >= 0 do
          %{widget | event_rate: rate}
        end
      end

    a11y_setter =
      quote do
        @doc "Sets accessibility annotations."
        @spec a11y(widget :: t(), a11y :: Plushie.Type.A11y.t()) :: t()
        def a11y(%__MODULE__{} = widget, a11y) do
          %{widget | a11y: Plushie.Type.A11y.cast(a11y)}
        end
      end

    prop_setters ++ [event_rate_setter, a11y_setter]
  end

  defp setter_guard(:number), do: quote(do: is_number(value))
  defp setter_guard(:string), do: quote(do: is_binary(value))
  defp setter_guard(:boolean), do: quote(do: is_boolean(value))
  defp setter_guard(:atom), do: quote(do: is_atom(value))
  defp setter_guard(:map), do: quote(do: is_map(value))
  defp setter_guard({:list, _}), do: quote(do: is_list(value))
  defp setter_guard(_), do: nil

  defp generate_build do
    quote do
      @doc "Converts this widget struct to a `ui_node()` map."
      @spec build(widget :: t()) :: Plushie.Widget.ui_node()
      def build(%__MODULE__{} = widget), do: Plushie.Widget.to_node(widget)
    end
  end

  defp generate_widget_protocol(
         _module,
         widget_type,
         type_string,
         container,
         props,
         events,
         event_specs
       ) do
    put_calls =
      Enum.map(props, fn {name, type, _opts} ->
        # Color needs casting in to_node because struct defaults bypass setters.
        # All other types store raw values -- Tree.normalize handles encoding.
        if type == :color do
          quote do
            props =
              Plushie.Widget.Build.put_if(
                props,
                widget.unquote(name),
                unquote(name),
                fn val -> Plushie.Type.Color.cast(val) end
              )
          end
        else
          quote do
            props =
              Plushie.Widget.Build.put_if(
                props,
                widget.unquote(name),
                unquote(name)
              )
          end
        end
      end)

    event_rate_put =
      quote do
        props = Plushie.Widget.Build.put_if(props, widget.event_rate, :event_rate)
      end

    a11y_put =
      quote do
        props = Plushie.Widget.Build.put_if(props, widget.a11y, :a11y)
      end

    children =
      if container do
        quote(do: Plushie.Widget.Build.children_to_nodes(widget.children))
      else
        quote(do: [])
      end

    # defimpl must be defined at the top level of the module, not inside a
    # function. We generate the AST here; it's injected via __before_compile__.
    quote do
      defimpl Plushie.Widget.WidgetProtocol do
        def to_node(widget) do
          props = %{}
          unquote_splicing(put_calls)
          unquote(event_rate_put)
          unquote(a11y_put)

          props =
            Map.put(props, :__widget__, %Plushie.Widget.Meta.Native{
              type: unquote(widget_type),
              events: unquote(events),
              event_specs: unquote(Macro.escape(event_specs))
            })

          %{
            id: widget.id,
            type: unquote(type_string),
            props: props,
            children: unquote(children)
          }
        end
      end
    end
  end

  @doc false
  def generate_prop_validation(props) do
    known_names =
      Enum.map(props, fn {name, _type, _opts} -> name end) ++ [:event_rate, :a11y]

    quote do
      unknown_keys = Keyword.keys(opts) -- unquote(known_names)

      if unknown_keys != [] do
        raise ArgumentError,
              "unknown option(s) #{inspect(unknown_keys)} for #{inspect(__MODULE__)}.new"
      end
    end
  end

  defp encoder_for_type(:color) do
    quote do
      fn val -> Plushie.Type.Color.cast(val) end
    end
  end

  defp encoder_for_type(_type) do
    # All other types store raw values. Tree.normalize handles wire encoding.
    quote do
      fn val -> val end
    end
  end

  @doc false
  def generate_commands(commands) do
    fns =
      Enum.map(commands, fn {name, params} ->
        param_names = Keyword.keys(params)

        args =
          [quote(do: widget_id) | Enum.map(param_names, fn p -> to_var(p) end)]

        payload_map =
          {:%{}, [],
           Enum.map(param_names, fn p ->
             {p, to_var(p)}
           end)}

        guards = build_command_guards(params)
        op_string = Atom.to_string(name)
        spec_ast = build_command_spec(name, params)

        if param_names == [] do
          quote do
            @doc "Sends the `#{unquote(op_string)}` command to the native widget."
            @spec unquote(spec_ast)
            def unquote(name)(widget_id) when is_binary(widget_id) do
              Plushie.Command.widget_command(widget_id, unquote(op_string), %{})
            end
          end
        else
          quote do
            @doc "Sends the `#{unquote(op_string)}` command to the native widget."
            @spec unquote(spec_ast)
            def unquote(name)(unquote_splicing(args))
                when is_binary(widget_id) and unquote(guards) do
              Plushie.Command.widget_command(
                widget_id,
                unquote(op_string),
                unquote(payload_map)
              )
            end
          end
        end
      end)

    quote do
      (unquote_splicing(fns))
    end
  end

  defp build_command_spec(name, params) do
    param_types = [quote(do: String.t()) | Enum.map(params, fn {_n, t} -> elixir_type_for(t) end)]
    return_type = quote(do: Plushie.Command.t())

    quote do
      unquote(name)(unquote_splicing(param_types)) :: unquote(return_type)
    end
  end

  defp build_command_guards([]), do: quote(do: true)

  defp build_command_guards(params) do
    guards =
      Enum.map(params, fn {name, type} ->
        var = to_var(name)
        guard_for_type(var, type)
      end)

    Enum.reduce(guards, fn right, left ->
      quote(do: unquote(left) and unquote(right))
    end)
  end

  defp guard_for_type(var, :number), do: quote(do: is_number(unquote(var)))
  defp guard_for_type(var, :string), do: quote(do: is_binary(unquote(var)))
  defp guard_for_type(var, :boolean), do: quote(do: is_boolean(unquote(var)))
  defp guard_for_type(var, :atom), do: quote(do: is_atom(unquote(var)))
  defp guard_for_type(var, :map), do: quote(do: is_map(unquote(var)))
  defp guard_for_type(var, :list), do: quote(do: is_list(unquote(var)))
  defp guard_for_type(var, {:list, _}), do: quote(do: is_list(unquote(var)))
  defp guard_for_type(_var, _), do: quote(do: true)

  # Build a simple AST variable reference from an atom name.
  defp to_var(name) when is_atom(name), do: {name, [], nil}
end
