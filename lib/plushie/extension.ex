defmodule Plushie.Extension do
  @moduledoc """
  Macro-based DSL for declaring Plushie widget extensions.

  Supports three kinds of extension:

  - `:native_widget` -- backed by a Rust crate implementing the
    `WidgetExtension` trait. Requires `rust_crate` and `rust_constructor`
    declarations.
  - `:widget` -- pure Elixir widget, either a direct node builder or a
    composite that defines `render/2` or `render/3`.
  - `:canvas_widget` -- pure Elixir canvas-based widget with internal
    state management and event transformation. Defines `render/3`
    (id, props, state), `handle_event/2` for event transformation,
    and optional `state` declarations for runtime-managed internal
    state. See the canvas_widget section below.

  ## Usage

      defmodule MyApp.Gauge do
        use Plushie.Extension, :native_widget

        widget :gauge

        prop :value, :number
        prop :min, :number, default: 0
        prop :max, :number, default: 100
        prop :color, :color, default: :blue
        prop :width, :length
        prop :height, :length

        rust_crate "native/my_gauge"
        rust_constructor "my_gauge::GaugeExtension::new()"

        event :value_changed, data: [value: :number]
        command :set_value, value: :number
      end

  ## Generated code

  The macro generates:

  - `type_names/0` -- returns `[:gauge]` (from the `widget` declaration)
  - `native_crate/0` -- returns the `rust_crate` path (native_widget only)
  - `rust_constructor/0` -- returns the Rust expression (native_widget only)
  - `new/2` -- creates a `%Module{}` struct (or a node map for composites)
  - Setter functions per prop for pipeline composition
  - `with_options/2` -- applies keyword options via setters
  - `build/1` -- converts the struct to a `ui_node()` map
  - `@type t`, `@type option` -- typespecs for dialyzer
  - `Plushie.Widget` protocol implementation
  - `__event_specs__/0`, `__event_spec__/1` -- typed event metadata
  - Command functions (native_widget only) that wrap
    `Plushie.Command.extension_command/3`

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

  If the using module defines `render/2` (leaf) or `render/3` (container),
  `new/2` delegates to it after resolving props:

      defmodule MyApp.LabeledInput do
        use Plushie.Extension, :widget

        widget :labeled_input, container: true

        prop :label, :string

        def render(id, props, children) do
          import Plushie.UI
          column id: id do
            text(props.label)
            Enum.map(children, & &1)
          end
        end
      end

  ### render/2 vs render/3

  Use `render/2` for leaf composites that do not accept children:

      def render(id, props) do
        %{id: id, type: "text", props: %{content: props.label}, children: []}
      end

  Use `render/3` for container composites that accept children. When
  `container: true` is set on the `widget` declaration, you must define
  `render/3` (not `render/2`):

      def render(id, props, children) do
        %{id: id, type: "column", props: %{}, children: children}
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

  @doc "Node type atoms this extension handles."
  @callback type_names() :: [atom()]

  @doc "Path to the Rust crate relative to the package root."
  @callback native_crate() :: String.t()

  @doc "Full Rust constructor expression for the extension."
  @callback rust_constructor() :: String.t()

  @optional_callbacks [native_crate: 0, rust_constructor: 0]

  # -- __using__ -------------------------------------------------------------

  @valid_kinds [:native_widget, :widget, :canvas_widget]

  defmacro __using__(kind) when kind not in [:native_widget, :widget, :canvas_widget] do
    raise ArgumentError,
          "Plushie.Extension kind must be one of #{inspect(@valid_kinds)}, got: #{inspect(kind)}"
  end

  defmacro __using__(kind) when kind in [:native_widget, :widget, :canvas_widget] do
    common =
      quote do
        @behaviour Plushie.Extension
        @_extension_kind unquote(kind)

        Module.register_attribute(__MODULE__, :_extension_props, accumulate: true)
        Module.register_attribute(__MODULE__, :_extension_commands, accumulate: true)
        Module.register_attribute(__MODULE__, :_extension_events, accumulate: true)
        Module.register_attribute(__MODULE__, :_extension_event_specs, accumulate: true)
        Module.put_attribute(__MODULE__, :_extension_widget, nil)
        Module.put_attribute(__MODULE__, :_extension_container, false)
      end

    canvas_widget_attrs =
      if kind == :canvas_widget do
        quote do
          Module.register_attribute(__MODULE__, :_extension_state_fields, accumulate: true)
        end
      end

    imports =
      case kind do
        :native_widget ->
          quote do
            import Plushie.Extension,
              only: [
                widget: 1,
                widget: 2,
                prop: 2,
                prop: 3,
                event: 1,
                event: 2,
                command: 1,
                command: 2,
                rust_crate: 1,
                rust_constructor: 1
              ]

            Module.put_attribute(__MODULE__, :_rust_crate, nil)
            Module.put_attribute(__MODULE__, :_rust_constructor, nil)
          end

        :canvas_widget ->
          quote do
            @behaviour Plushie.Extension.CanvasWidget

            import Plushie.Extension,
              only: [
                widget: 1,
                widget: 2,
                prop: 2,
                prop: 3,
                state: 1,
                event: 1,
                event: 2
              ]

            import Plushie.UI
          end

        :widget ->
          quote do
            import Plushie.Extension,
              only: [widget: 1, widget: 2, prop: 2, prop: 3, event: 1, event: 2]

            import Plushie.UI
          end
      end

    before_compile =
      quote do
        @before_compile Plushie.Extension
      end

    [common, canvas_widget_attrs, imports, before_compile]
  end

  # -- DSL macros ------------------------------------------------------------

  @doc "Declares the widget type name. Pass `container: true` for container widgets."
  defmacro widget(type_name, opts \\ []) do
    quote do
      if @_extension_widget do
        IO.warn(
          "widget type already declared as #{inspect(@_extension_widget)}, overwriting with #{inspect(unquote(type_name))}"
        )
      end

      @_extension_widget unquote(type_name)
      @_extension_container unquote(Keyword.get(opts, :container, false))
    end
  end

  @doc "Declares a prop with name, type, and optional default."
  defmacro prop(name, type, opts \\ []) do
    quote do
      @_extension_props {unquote(name), unquote(type), unquote(opts)}
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

  ## Block form

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
      @_extension_events name
      @_extension_event_specs {name, spec}
    end
  end

  defmacro event(name, opts) do
    caller = __CALLER__
    validate_event_name!(name, caller)
    opts = expand_type_aliases(opts, caller)
    spec = parse_event_opts(opts, caller)
    validate_event_spec!(name, spec, caller)

    quote bind_quoted: [name: name, spec: Macro.escape(spec)] do
      @_extension_events name
      @_extension_event_specs {name, spec}
    end
  end

  @doc """
  Declares internal state fields for a canvas_widget.

  State fields are managed by the runtime, not the app model.
  They persist across renders and are passed to `render/3` and
  `handle_event/2`.

      state hover: nil, drag: :none, animation_progress: 0.0
  """
  defmacro state(fields) when is_list(fields) do
    quote do
      for {name, default} <- unquote(fields) do
        @_extension_state_fields {name, default}
      end
    end
  end

  @doc "Declares a command (native_widget only) with optional typed params."
  defmacro command(name, params \\ []) do
    quote do
      @_extension_commands {unquote(name), unquote(params)}
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
    kind = Module.get_attribute(env.module, :_extension_kind)
    widget_type = Module.get_attribute(env.module, :_extension_widget)
    container = Module.get_attribute(env.module, :_extension_container)
    props = Module.get_attribute(env.module, :_extension_props) |> Enum.reverse()
    commands = Module.get_attribute(env.module, :_extension_commands) |> Enum.reverse()
    events = Module.get_attribute(env.module, :_extension_events) |> Enum.reverse()
    event_specs = Module.get_attribute(env.module, :_extension_event_specs) |> Enum.reverse()

    validate_declarations!(env, kind, widget_type, events)
    validate_prop_types!(env, props)
    validate_command_types!(commands)
    warn_duplicate_props(env, props)
    warn_duplicate_events(env, events)
    validate_reserved_names!(env, props)

    if kind == :canvas_widget do
      validate_canvas_widget!(env)
    else
      validate_render_arity!(env, container)
    end

    rust_crate_val = Module.get_attribute(env.module, :_rust_crate)
    rust_constructor_val = Module.get_attribute(env.module, :_rust_constructor)
    has_render_3 = Module.defines?(env.module, {:render, 3})
    is_composite = Module.defines?(env.module, {:render, 2}) or has_render_3
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

    widget_code =
      if kind == :canvas_widget do
        state_fields =
          (Module.get_attribute(env.module, :_extension_state_fields) || [])
          |> Enum.reverse()

        prop_validation = generate_prop_validation(props)

        generate_canvas_widget_new(
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
        if is_composite do
          prop_validation = generate_prop_validation(props)
          has_handle_event = Module.defines?(env.module, {:handle_event, 2})

          generate_composite_new(%{
            module: env.module,
            widget_type: widget_type,
            container: container,
            props: props,
            events: events,
            event_specs: event_specs,
            prop_extract: prop_validation,
            has_render_3: has_render_3,
            has_handle_event: has_handle_event
          })
        else
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
      end

    command_fns = generate_commands(commands)
    prop_names_fn = generate_prop_names(props)

    quote do
      unquote(behaviour_fns)
      unquote(widget_code)
      unquote(command_fns)
      unquote(prop_names_fn)
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

        %{carrier: :data, fields: fields}

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

    Enum.reduce(stmts, %{carrier: :none}, fn
      {:value, _meta, [type]}, %{carrier: :none} ->
        %{carrier: :value, type: type}

      {:data, _meta, [[do: inner_block]]}, %{carrier: :none} ->
        %{carrier: :data, fields: parse_data_fields(inner_block, caller)}

      {:data, _meta, [fields]}, %{carrier: :none} when is_list(fields) ->
        unless Keyword.keyword?(fields) do
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description: "event data: must be a keyword list of [field: type]"
        end

        %{carrier: :data, fields: fields}

      _other, acc ->
        acc
    end)
  end

  defp block_to_list({:__block__, _, stmts}), do: stmts
  defp block_to_list(stmt), do: [stmt]

  defp parse_data_fields({:__block__, _, stmts}, caller), do: parse_data_stmts(stmts, caller)
  defp parse_data_fields(stmt, caller), do: parse_data_stmts([stmt], caller)

  defp parse_data_stmts(stmts, caller) do
    Enum.map(stmts, fn
      {:field, _meta, [name, type]} when is_atom(name) ->
        {name, type}

      other ->
        raise CompileError,
          file: caller.file,
          line: caller.line,
          description:
            "expected `field :name, :type` inside data block, got: #{Macro.to_string(other)}"
    end)
  end

  @doc false
  @spec validate_event_spec!(
          name :: atom(),
          spec :: Plushie.Event.BuiltinSpecs.t(),
          caller :: Macro.Env.t()
        ) ::
          :ok | [any()]
  def validate_event_spec!(name, spec, caller) do
    case spec do
      %{carrier: :value, type: type} ->
        unless Plushie.Event.EventType.valid_type?(type) do
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "event #{inspect(name)} has invalid value type #{inspect(type)}. " <>
                "Use a built-in type (:number, :string, :boolean, :any) or a module implementing Plushie.Event.EventType."
        end

      %{carrier: :data, fields: fields} ->
        for {field_name, type} <- fields do
          unless Plushie.Event.EventType.valid_type?(type) do
            raise CompileError,
              file: caller.file,
              line: caller.line,
              description:
                "event #{inspect(name)} field #{inspect(field_name)} has invalid type #{inspect(type)}. " <>
                  "Use a built-in type (:number, :string, :boolean, :any) or a module implementing Plushie.Event.EventType."
          end
        end

      %{carrier: :none} ->
        :ok
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

    # All extension kinds can declare events via the event macro.
  end

  defp validate_prop_types!(env, props) do
    for {name, type, _opts} <- props do
      unless valid_type?(type) do
        raise CompileError,
          file: env.file,
          line: 0,
          description:
            "unsupported prop type #{inspect(type)} for prop #{inspect(name)} in #{inspect(env.module)}. Supported: #{inspect(@known_prop_types)}"
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

  defp validate_render_arity!(env, container) do
    has_render_2 = Module.defines?(env.module, {:render, 2})
    has_render_3 = Module.defines?(env.module, {:render, 3})

    if container and has_render_2 and not has_render_3 do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "#{inspect(env.module)} declares container: true but defines render/2 instead of render/3. Container widgets must accept children via render/3."
    end
  end

  defp validate_canvas_widget!(env) do
    unless Module.defines?(env.module, {:render, 3}) do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "#{inspect(env.module)} is a :canvas_widget but does not define render/3. " <>
            "Canvas widgets must define render(id, props, state)."
    end

    # handle_event/2 is optional. If not defined, a default passthrough
    # is generated. Read-only canvas widgets (gauges, charts, etc.)
    # don't need event transformation.
  end

  defp generate_canvas_widget_new(
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

    default_handle_event =
      unless has_handle_event do
        quote do
          @doc "Default event handler -- all events consumed (opaque widget)."
          def handle_event(_event, _state), do: :consumed
        end
      end

    quote do
      @doc "Returns the initial internal state for this canvas widget."
      @spec __initial_state__() :: map()
      def __initial_state__, do: unquote(state_defaults)

      @doc "Returns true for canvas_widget extension modules."
      @spec __canvas_widget__?() :: true
      def __canvas_widget__?, do: true

      unquote(default_handle_event)

      defstruct unquote(Macro.escape(struct_fields))

      defimpl Plushie.Widget do
        @doc """
        Converts the canvas_widget struct to a placeholder node.

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
            type: "canvas_widget",
            props: %{
              __canvas_widget__: unquote(module),
              __canvas_widget_props__: props,
              __extension_widget_type__: unquote(widget_type),
              __extension_widget_events__: unquote(events),
              __extension_widget_event_specs__: unquote(Macro.escape(event_specs))
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
        @impl Plushie.Extension
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

        @impl Plushie.Extension
        def native_crate, do: unquote(rust_crate_val)

        @impl Plushie.Extension
        def rust_constructor, do: unquote(rust_constructor_val)
      end
    else
      base
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

  defp generate_composite_new(config) do
    %{
      module: module,
      widget_type: widget_type,
      container: container,
      props: props,
      events: events,
      event_specs: event_specs,
      prop_extract: prop_extract,
      has_render_3: has_render_3,
      has_handle_event: has_handle_event
    } = config

    prop_struct_fields =
      for {name, _type, opts} <- props do
        {name, Keyword.get(opts, :default)}
      end

    has_events = events != [] or has_handle_event
    is_container = container or has_render_3

    handler_code =
      generate_composite_handler_code(
        module,
        widget_type,
        events,
        event_specs,
        has_events,
        has_handle_event
      )

    new_fn = generate_composite_new_fn(prop_struct_fields, prop_extract, is_container, has_events)

    quote do
      unquote(handler_code)
      unquote(new_fn)
    end
  end

  defp generate_composite_handler_code(
         _module,
         _widget_type,
         _events,
         _event_specs,
         false,
         _has_handle_event
       ),
       do: nil

  defp generate_composite_handler_code(
         module,
         widget_type,
         events,
         event_specs,
         true,
         has_handle_event
       ) do
    default_handle_event =
      unless has_handle_event do
        quote do
          @doc "Default event handler -- all events consumed (opaque widget)."
          def handle_event(_event, _state), do: :consumed
        end
      end

    quote do
      unquote(default_handle_event)

      @doc false
      defp __inject_handler_meta__(node) do
        meta = Map.get(node, :meta, %{})

        meta =
          meta
          |> Map.put(:__widget_event_handler__, unquote(module))
          |> Map.put(:__extension_widget_type__, unquote(widget_type))
          |> Map.put(:__extension_widget_events__, unquote(events))
          |> Map.put(:__extension_widget_event_specs__, unquote(Macro.escape(event_specs)))

        Map.put(node, :meta, meta)
      end
    end
  end

  defp generate_composite_new_fn(prop_struct_fields, prop_extract, is_container, has_events) do
    render_call =
      if is_container do
        quote do
          {children, opts} = Keyword.pop(opts, :do, [])
          children = List.wrap(children)
        end
      end

    render_invoke =
      if is_container do
        quote(do: render(id, props_map, children))
      else
        quote(do: render(id, props_map))
      end

    wrap_result =
      if has_events do
        quote(do: __inject_handler_meta__(result))
      else
        quote(do: result)
      end

    quote do
      @spec new(id :: String.t(), opts :: keyword()) :: Plushie.Widget.ui_node()
      def new(id, opts \\ []) when is_binary(id) do
        unquote(render_call)
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

        result = unquote(render_invoke)
        unquote(wrap_result)
      end
    end
  end

  # -- Struct-based widget generation -----------------------------------------
  #
  # For non-composite widgets (no render/2 or render/3), we generate:
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
        if(container, do: [{:children, quote(do: [Plushie.Widget.ui_node()])}], else: []) ++
        [
          {:event_rate, quote(do: pos_integer() | nil)},
          {:a11y, quote(do: Plushie.Type.A11y.t() | nil)}
        ]

    option_variants =
      Enum.map(props, fn {name, type, _opts} ->
        quote(do: {unquote(name), unquote(elixir_type_for(type))})
      end) ++
        [
          quote(do: {:event_rate, pos_integer()}),
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
        @doc "Sets the maximum event rate (events per second) for this widget's coalescable events."
        @spec event_rate(widget :: t(), rate :: pos_integer()) :: t()
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
      defimpl Plushie.Widget do
        def to_node(widget) do
          props = %{}
          unquote_splicing(put_calls)
          unquote(event_rate_put)
          unquote(a11y_put)

          props =
            props
            |> Map.put(:__extension_widget_type__, unquote(widget_type))
            |> Map.put(:__extension_widget_events__, unquote(events))
            |> Map.put(:__extension_widget_event_specs__, unquote(Macro.escape(event_specs)))

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
      Enum.map(props, fn {name, _type, _opts} -> name end) ++ [:event_rate, :a11y, :do]

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
            @doc "Sends the `#{unquote(op_string)}` command to the extension widget."
            @spec unquote(spec_ast)
            def unquote(name)(widget_id) when is_binary(widget_id) do
              Plushie.Command.extension_command(widget_id, unquote(op_string), %{})
            end
          end
        else
          quote do
            @doc "Sends the `#{unquote(op_string)}` command to the extension widget."
            @spec unquote(spec_ast)
            def unquote(name)(unquote_splicing(args))
                when is_binary(widget_id) and unquote(guards) do
              Plushie.Command.extension_command(
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
