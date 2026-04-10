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
            import Plushie.Widget,
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
            import Plushie.Widget,
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

  # -- DSL macros ------------------------------------------------------------

  @doc """
  Declares the widget type name. Pass `container: true` for container widgets.

  Accepts an optional do-block for grouping field and positional declarations:

      widget :checkbox do
        field :label, :string, doc: "Text label."
        field :is_toggled, :boolean, option: false, doc: "Checked state."
        positional [:label, :is_toggled]
      end

  Without a block, declares the type name only (e.g. `widget :space`).
  """
  # When Elixir parses `widget :name, key: val do ... end`, the keyword
  # opts and do-block arrive as separate arguments (arity 3). Merge them
  # so the two-arg clause handles everything uniformly.
  defmacro widget(type_name, opts, do_block) do
    quote do: widget(unquote(type_name), unquote(opts ++ do_block))
  end

  defmacro widget(type_name, opts \\ []) do
    validate_widget_type_name!(type_name, __CALLER__)
    {block, opts} = Keyword.pop(opts, :do, nil)
    container = Keyword.get(opts, :container, false)

    quote do
      if @_widget_type_name do
        IO.warn(
          "widget type already declared as #{inspect(@_widget_type_name)}, overwriting with #{inspect(unquote(type_name))}"
        )
      end

      @_widget_type_name unquote(type_name)
      @_widget_container unquote(container)
      unquote(block)
    end
  end

  defp validate_widget_type_name!(type_name, caller) do
    unless is_atom(type_name) do
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description: "widget type name must be an atom, got: #{inspect(type_name)}"
    end
  end

  @doc """
  Declares which props are positional arguments in `new/N`.

  Props listed here appear as positional arguments before the `opts`
  keyword in the generated constructor. The order matters: it
  determines the argument order.

  Props with `option: false` are excluded from `with_options/2` and
  `__field_keys__/0` but still generate struct fields and setters.

      positional [:label, :is_toggled]

  Generates `new(id, label, is_toggled, opts \\\\ [])` instead of the
  default `new(id, opts \\\\ [])`.
  """
  defmacro positional(names) when is_list(names) do
    quote do
      @_widget_positional unquote(names)
    end
  end

  @doc """
  Declares a typed event emitted by a native or canvas widget.

  Supports three forms:

  ## No payload

      event :cleared

  ## Typed value (goes in `WidgetEvent.value`)

      event :select, value: :float

  ## Structured fields (goes in `WidgetEvent.value` as an atom-keyed map)

      event :change, fields: [hue: :float, saturation: :float]

  ## Block form (Ecto-style)

      event :change do
        field :hue, :float
        field :saturation, :float
        field :modifier, :string, required: false
      end

  All fields are required by default. Use `required: false` to make
  a field optional. Optional fields may be omitted from emitted data
  without raising an error.

  ## Block form (nested fields)

      event :change do
        fields do
          field :hue, :float
          field :saturation, :float
        end
      end

  `value:` and `fields:` are mutually exclusive.

  Type identifiers can be built-in atoms (`:float`, `:string`,
  `:boolean`, `:any`) or modules with a `parse/1` function.
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

  Supports two forms:

      # Keyword form (untyped, original)
      state hover: nil, drag: :none

      # Block form (typed)
      state do
        field :hover, :boolean, default: false
        field :drag, :atom, default: :none
      end
  """
  defmacro state(fields_or_block)

  defmacro state(do: block) do
    stmts = block_to_list(block)
    caller = __CALLER__

    parsed =
      Enum.map(stmts, fn
        {:field, _meta, [name, type]} when is_atom(name) ->
          validate_state_field_type!(name, type, caller)
          {name, type, nil}

        {:field, _meta, [name, type, opts]} when is_atom(name) and is_list(opts) ->
          validate_state_field_type!(name, type, caller)
          {name, type, Keyword.get(opts, :default)}

        other ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description:
              "expected `field :name, :type` inside state block, got: #{Macro.to_string(other)}"
      end)

    quote do
      for {name, type, default} <- unquote(Macro.escape(parsed)) do
        @_widget_state_fields {name, default, type}
      end
    end
  end

  defmacro state(fields) when is_list(fields) do
    quote do
      for {name, default} <- unquote(fields) do
        @_widget_state_fields {name, default}
      end
    end
  end

  @doc """
  Declares an optional cache key function for expensive widgets.

  When declared, the normalizer calls this function before `view/3`.
  If the returned key matches the previous render's key, the cached
  normalized output is reused and `view/3` is skipped entirely.

      cache_key fn props, state ->
        {props.data_version, state.zoom_level}
      end

  Only applicable to `:widget` kind (not `:native_widget`).
  """
  defmacro cache_key(fun) do
    escaped = Macro.escape(fun)

    quote do
      @_widget_cache_key_fn unquote(escaped)
    end
  end

  defp validate_state_field_type!(name, type, caller) do
    unless valid_type?(type) do
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description:
          "unsupported state field type #{inspect(type)} for field #{inspect(name)}. " <>
            "Use a primitive shortcut (:string, :float, etc.) or a Plushie.Type module."
    end
  end

  @doc """
  Declares a typed field on the widget.

  At the widget level, accumulates into `@_widget_props`:

      field :value, :float
      field :color, Plushie.Type.Color, default: :blue

  Inside an `event` do-block, `field` calls are consumed as AST by the
  event macro and parsed into the event spec. They are never expanded
  as macros in that context.
  """
  defmacro field(name, type, opts \\ []) do
    quote do
      @_widget_props {unquote(name), unquote(type), unquote(opts)}
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

  # Known field options consumed by the widget macro. Anything else is
  # treated as a type constraint and forwarded to constrain_guard/2.
  @known_field_opts [:doc, :default, :option, :wire_name, :required, :cast, :merge]

  # Type validation delegates to Plushie.Type.resolve/1 at compile time.

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

    positional = Module.get_attribute(env.module, :_widget_positional) || []
    validate_positional!(env, positional, props)

    rust_crate_val = Module.get_attribute(env.module, :_rust_crate)
    rust_constructor_val = Module.get_attribute(env.module, :_rust_constructor)
    has_view_3 = Module.defines?(env.module, {:view, 3})
    has_view = Module.defines?(env.module, {:view, 2}) or has_view_3

    if has_view do
      validate_widget_callbacks!(env, has_view_3)
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
        # Struct-only widgets (native_widget or builtin, no view callback).
        generate_struct_widget(
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

    command_fns = generate_commands(commands)
    prop_names_fn = generate_prop_names(props)
    dsl_macro = generate_dsl_macro(widget_type, props)

    cache_key_fn =
      if kind == :widget do
        generate_cache_key_fn(Module.get_attribute(env.module, :_widget_cache_key_fn))
      end

    widget_info_fn =
      generate_widget_info(kind, type_string, props, events, state_fields, commands)

    moduledoc_update =
      generate_moduledoc_update(
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

        quote do
          unquote(mod).new(unquote(id), unquote(opts))
          |> Plushie.Widget.to_node()
        end
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

      {:fields, fields} when is_list(fields) ->
        {:fields, Enum.map(fields, fn {k, v} -> {k, maybe_expand_alias(v, caller)} end)}

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
    {doc, opts} = Keyword.pop(opts, :doc)
    has_value = Keyword.has_key?(opts, :value)
    has_fields = Keyword.has_key?(opts, :fields)

    if has_value and has_fields do
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description: "event cannot declare both value: and fields: (they are mutually exclusive)"
    end

    spec =
      cond do
        has_value ->
          %{carrier: :value, type: Keyword.fetch!(opts, :value)}

        has_fields ->
          fields = Keyword.fetch!(opts, :fields)

          unless is_list(fields) and Keyword.keyword?(fields) do
            raise CompileError,
              file: caller.file,
              line: caller.line,
              description:
                "event fields: must be a keyword list of [field: type], got: #{inspect(fields)}"
          end

          %{carrier: :value, fields: fields, required: Keyword.keys(fields)}

        opts == [] ->
          %{carrier: :none}

        true ->
          raise CompileError,
            file: caller.file,
            line: caller.line,
            description: "event options must include value: or fields:, got: #{inspect(opts)}"
      end

    if doc, do: Map.put(spec, :doc, doc), else: spec
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

        {:fields, _meta, [[do: inner_block]]}, %{carrier: :none} ->
          parse_data_block_to_spec(block_to_list(inner_block), caller)

        {:fields, _meta, [fields]}, %{carrier: :none} when is_list(fields) ->
          unless Keyword.keyword?(fields) do
            raise CompileError,
              file: caller.file,
              line: caller.line,
              description: "event fields: must be a keyword list of [field: type]"
          end

          %{carrier: :value, fields: fields, required: Keyword.keys(fields)}

        _other, acc ->
          acc
      end)
    end
  end

  # Parses a list of `field` statements into a data spec with required tracking.
  defp parse_data_block_to_spec(stmts, caller) do
    {fields, required} = parse_data_stmts(stmts, caller)
    %{carrier: :value, fields: fields, required: required}
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

      %{carrier: :value, fields: fields} ->
        Enum.each(fields, fn {field_name, type} ->
          validate_event_field_type!(name, field_name, type, caller)
        end)

      %{carrier: :none} ->
        :ok
    end
  end

  defp validate_event_field_type!(event_name, field_name, type, caller) do
    unless Plushie.Type.valid_event_type?(type) do
      context =
        if field_name,
          do: "field #{inspect(field_name)} has",
          else: "has"

      raise CompileError,
        file: caller.file,
        line: caller.line,
        description:
          "event #{inspect(event_name)} #{context} invalid type #{inspect(type)}. " <>
            "Use a built-in type (:float, :string, :boolean, :any) or a module with parse/1."
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
    for {name, type, opts} <- props do
      unless valid_type?(type) do
        raise CompileError,
          file: env.file,
          line: 0,
          description:
            "unsupported field type #{inspect(type)} for field #{inspect(name)} in #{inspect(env.module)}. " <>
              "Use a primitive shortcut (:string, :float, etc.), a Plushie.Type module, " <>
              "or a composite ({:list, :type})."
      end

      validate_field_constraints!(env, name, type, opts)
    end
  end

  defp validate_field_constraints!(env, name, type, opts) do
    constraint_opts = Keyword.drop(opts, @known_field_opts)

    case {constraint_opts, Plushie.Type.resolve(type)} do
      {[], _} ->
        :ok

      {_, {:composite, _}} ->
        constraint_error!(
          env,
          name,
          constraint_opts,
          "composite types do not support constraints"
        )

      {_, module} ->
        validate_module_constraints!(env, name, module, constraint_opts)
    end
  end

  defp validate_module_constraints!(env, name, module, constraint_opts) do
    Code.ensure_compiled(module)

    unless function_exported?(module, :field_options, 0) do
      constraint_error!(
        env,
        name,
        constraint_opts,
        "#{inspect(module)} does not support constraints (no field_options/0)"
      )
    end

    allowed = module.field_options()

    for {key, _val} <- constraint_opts, key not in allowed do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "field #{inspect(name)} in #{inspect(env.module)} has unknown constraint " <>
            "#{inspect(key)}. #{inspect(module)} supports: #{inspect(allowed)}"
    end
  end

  defp constraint_error!(env, name, constraint_opts, reason) do
    raise CompileError,
      file: env.file,
      line: 0,
      description:
        "field #{inspect(name)} in #{inspect(env.module)} has constraint options " <>
          "#{inspect(Keyword.keys(constraint_opts))} but #{reason}"
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

  @reserved_prop_names [:id, :type, :children, :do]

  defp validate_reserved_names!(env, props) do
    for {name, _type, _opts} <- props, name in @reserved_prop_names do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "field name #{inspect(name)} is reserved in #{inspect(env.module)}. " <>
            "Reserved names: #{inspect(@reserved_prop_names)}"
    end
  end

  defp validate_positional!(env, positional, props) do
    prop_names = Enum.map(props, fn {name, _, _} -> name end)

    for name <- positional do
      unless name in prop_names do
        raise CompileError,
          file: env.file,
          line: 0,
          description:
            "positional #{inspect(name)} is not a declared field in #{inspect(env.module)}. " <>
              "Declared fields: #{inspect(prop_names)}"
      end
    end
  end

  defp validate_widget_callbacks!(env, has_view_3) do
    has_view_2 = Module.defines?(env.module, {:view, 2})

    unless has_view_2 or has_view_3 do
      raise CompileError,
        file: env.file,
        line: 0,
        description: "#{inspect(env.module)} must define view/2 or view/3."
    end

    has_handle_event = Module.defines?(env.module, {:handle_event, 2})
    state_fields = Module.get_attribute(env.module, :_widget_state_fields) || []

    if has_view_3 and not has_view_2 and state_fields == [] and not has_handle_event do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "#{inspect(env.module)} defines view/3 (stateful) but declares no state fields. " <>
            "Use `state field_name: default` to declare state, or define view/2 for stateless widgets."
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

    # Struct fields: :id + declared props
    struct_fields = [{:id, nil} | prop_struct_fields]

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
        prop_defaults = unquote(Macro.escape(prop_struct_fields))
        unquote(prop_extract)

        props_map =
          prop_defaults
          |> Enum.map(fn {name, default} ->
            {name, Keyword.get(opts, name, default)}
          end)
          |> Enum.reject(fn {_name, val} -> is_nil(val) end)
          |> Map.new()

        struct!(__MODULE__, Map.put(props_map, :id, id))
      end
    end
  end

  # Widget participates in event dispatch if it declares events,
  # has state fields, or defines handle_event/2 explicitly.
  defp participates_in_dispatch?(has_handle_event, events, state_fields) do
    has_handle_event or events != [] or state_fields != []
  end

  defp valid_type?(type) when is_atom(type) do
    # Known shortcuts are valid by definition (avoids compile-order issues).
    Plushie.Type.shortcut?(type) or type_module?(type)
  end

  defp valid_type?({:list, inner}), do: valid_type?(inner)
  defp valid_type?({:map, {k, v}}), do: valid_type?(k) and valid_type?(v)

  defp valid_type?({:map, fields}) when is_list(fields),
    do: Enum.all?(fields, fn {_, t} -> valid_type?(t) end)

  defp valid_type?({:tuple, types}) when is_list(types), do: Enum.all?(types, &valid_type?/1)
  defp valid_type?({:enum, values}) when is_list(values), do: true
  defp valid_type?({:union, types}) when is_list(types), do: Enum.all?(types, &valid_type?/1)
  defp valid_type?(_), do: false

  # Check if a module is a valid Plushie.Type module. Uses ensure_compiled
  # so that compile-order between widget and type modules is resolved
  # automatically (ensure_loaded would fail for not-yet-compiled modules
  # in the same project).
  defp type_module?(module) do
    case Code.ensure_compiled(module) do
      {:module, _} -> function_exported?(module, :typespec, 0)
      {:error, _} -> false
    end
  end

  # -- Moduledoc generation ---------------------------------------------------

  @doc false
  def generate_moduledoc_update(
        env,
        props,
        positional,
        events,
        event_specs,
        state_fields_raw,
        commands
      ) do
    existing = Module.get_attribute(env.module, :moduledoc)

    existing_text =
      case existing do
        {_line, text} when is_binary(text) -> text
        text when is_binary(text) -> text
        _ -> nil
      end

    if existing_text do
      generated =
        generate_moduledoc_sections(
          env.module,
          props,
          positional,
          events,
          event_specs,
          state_fields_raw,
          commands
        )

      if generated != "" do
        new_doc = existing_text <> "\n\n" <> generated

        quote do
          @moduledoc unquote(new_doc)
        end
      end
    end
  end

  @doc false
  def generate_moduledoc_sections(
        module,
        props,
        positional,
        events,
        event_specs,
        state_fields_raw,
        commands
      ) do
    sections =
      [
        generate_props_section(props, positional),
        generate_events_section(events, event_specs),
        generate_constructor_section(module, positional),
        generate_state_section(state_fields_raw),
        generate_commands_section(commands)
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(sections, "\n\n")
  end

  defp generate_props_section([], _positional), do: nil

  defp generate_props_section(props, positional) do
    rows =
      Enum.map(props, fn {name, type, opts} ->
        type_str = type_display_string(type) |> escape_table_pipes()
        is_positional = name in positional
        has_default = Keyword.has_key?(opts, :default)
        is_option = Keyword.get(opts, :option, true)

        default_str =
          cond do
            has_default -> "`#{inspect(Keyword.get(opts, :default))}`"
            is_positional and not is_option -> "required"
            true -> "`nil`"
          end

        desc = Keyword.get(opts, :doc, "")

        "| `#{name}` | `#{type_str}` | #{default_str} | #{desc} |"
      end)

    header =
      "## Props\n\n" <>
        "| Name | Type | Default | Description |\n" <>
        "|------|------|---------|-------------|"

    header <> "\n" <> Enum.join(rows, "\n")
  end

  defp generate_events_section([], _event_specs), do: nil

  defp generate_events_section(events, event_specs) do
    specs_map = Map.new(event_specs)

    rows =
      Enum.map(events, fn name ->
        spec = Map.get(specs_map, name, %{carrier: :none})
        type_str = event_spec_display(spec) |> escape_table_pipes()
        doc = Map.get(spec, :doc, "")
        "| `:#{name}` | #{type_str} | #{doc} |"
      end)

    header =
      "## Events\n\n" <>
        "| Event | Type | Description |\n" <>
        "|-------|------|-------------|"

    header <> "\n" <> Enum.join(rows, "\n")
  end

  defp generate_constructor_section(_module, []), do: nil

  defp generate_constructor_section(module, positional) do
    short = module |> Module.split() |> List.last()
    args = Enum.join(positional, ", ")

    "## Constructor\n\n" <>
      "    #{short}.new(id, #{args})\n" <>
      "    #{short}.new(id, #{args}, opts)"
  end

  defp generate_state_section([]), do: nil

  defp generate_state_section(state_fields_raw) do
    rows =
      Enum.map(state_fields_raw, fn
        {name, default, type} ->
          type_str = type_display_string(type) |> escape_table_pipes()
          "| `#{name}` | `#{type_str}` | `#{inspect(default)}` |"

        {name, default} ->
          "| `#{name}` | `term()` | `#{inspect(default)}` |"
      end)

    header =
      "## Internal State\n\n" <>
        "| Field | Type | Default |\n" <>
        "|-------|------|---------|"

    header <> "\n" <> Enum.join(rows, "\n")
  end

  defp generate_commands_section([]), do: nil

  defp generate_commands_section(commands) do
    rows =
      Enum.map(commands, fn {name, params} ->
        param_str =
          if params == [] do
            "none"
          else
            Enum.map_join(params, ", ", fn {pname, ptype} ->
              "`#{pname}: #{type_display_string(ptype)}`"
            end)
          end

        "| `:#{name}` | #{param_str} |"
      end)

    header =
      "## Commands\n\n" <>
        "| Command | Params |\n" <>
        "|---------|--------|"

    header <> "\n" <> Enum.join(rows, "\n")
  end

  defp event_spec_display(%{carrier: :none}), do: "none"

  defp event_spec_display(%{carrier: :value, type: type}) do
    "`value: #{type_display_string(type)}`"
  end

  defp event_spec_display(%{carrier: :value, fields: fields}) do
    fields_str =
      Enum.map_join(fields, ", ", fn {name, type} ->
        "#{name}: #{type_display_string(type)}"
      end)

    "`value: %{#{fields_str}}`"
  end

  @doc false
  def type_display_string(type) do
    case Plushie.Type.resolve(type) do
      {:composite, {:list, inner}} ->
        "[#{type_display_string(inner)}]"

      {:composite, {:map, {key_type, val_type}}} ->
        "%{#{type_display_string(key_type)} => #{type_display_string(val_type)}}"

      {:composite, {:map, fields}} when is_list(fields) ->
        inner =
          Enum.map_join(fields, ", ", fn {name, t} -> "#{name}: #{type_display_string(t)}" end)

        "%{#{inner}}"

      {:composite, {:tuple, types}} ->
        inner = Enum.map_join(types, ", ", &type_display_string/1)
        "{#{inner}}"

      {:composite, {:enum, values}} ->
        Enum.map_join(values, " | ", &inspect/1)

      {:composite, {:union, types}} ->
        Enum.map_join(types, " | ", &type_display_string/1)

      module ->
        try do
          Macro.to_string(module.typespec())
        rescue
          _ -> inspect(module)
        end
    end
  end

  # Escape pipe characters inside markdown table cells so that ExDoc does not
  # split on them. Uses the HTML entity which renders as a literal pipe.
  defp escape_table_pipes(str), do: String.replace(str, "|", "\\|")

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
  def generate_cache_key_fn(nil), do: nil

  @doc false
  def generate_cache_key_fn(fun_ast) do
    quote do
      @doc false
      @spec __cache_key__(map(), map()) :: term()
      def __cache_key__(props, state) do
        fun = unquote(fun_ast)
        fun.(props, state)
      end
    end
  end

  def generate_prop_names(props) do
    known =
      Enum.map(props, fn {name, _type, _opts} -> name end)

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
  def generate_struct_widget(module, kind, widget_type, container, props, extra \\ []) do
    type_string = Atom.to_string(widget_type)
    positional = Keyword.get(extra, :positional, [])
    events = Keyword.get(extra, :events, [])
    event_specs = Keyword.get(extra, :event_specs, [])

    # Props with option: false are excluded from option_keys and with_options.
    option_props = Enum.filter(props, fn {_n, _t, opts} -> Keyword.get(opts, :option, true) end)

    struct_def = generate_struct_and_types(props, container)
    new_fn = generate_struct_new(container, positional, props)
    with_options_fn = generate_with_options(option_props)
    setters = generate_setters(props, positional)
    dsl_fns = generate_dsl_buildable(option_props)
    build_fn = generate_build(container)
    container_fns = if container, do: generate_container_helpers(), else: nil

    protocol_impl =
      generate_widget_protocol(
        module,
        kind,
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
      unquote(container_fns)
      unquote(protocol_impl)
    end
  end

  # -- Struct-based widget generation -----------------------------------------
  #
  # For struct-only widgets (native_widget) (no view/2 or view/3), we generate:
  # - defstruct with all declared fields + :id
  # - @type t with proper field types
  # - @type option union of keyword tuples
  # - new/2 that creates a struct and applies keyword options
  # - with_options/2 that reduces options through setter functions
  # - A setter function per field with encoding and guards
  # - build/1 convenience that calls the protocol
  # - Plushie.Widget protocol implementation (to_node)

  defp generate_struct_and_types(props, container) do
    prop_fields =
      Enum.map(props, fn {name, _type, opts} -> {name, Keyword.get(opts, :default)} end)

    struct_fields =
      [{:id, nil} | prop_fields] ++
        if(container, do: [{:children, []}], else: [])

    escaped_struct_fields = Macro.escape(struct_fields)

    prop_type_fields = Enum.map(props, &prop_type_ast/1)

    type_fields =
      [{:id, quote(do: String.t())} | prop_type_fields] ++
        if(container,
          do: [{:children, quote(do: [Plushie.Widget.ui_node()])}],
          else: []
        )

    option_props =
      Enum.filter(props, fn {_n, _t, opts} -> Keyword.get(opts, :option, true) end)

    option_variants =
      Enum.map(option_props, fn {name, type, _opts} ->
        type_ast = option_type_for(type)
        quote(do: {unquote(name), unquote(type_ast)})
      end)

    quote do
      @enforce_keys [:id]
      defstruct unquote(escaped_struct_fields)

      @type t :: %__MODULE__{unquote_splicing(type_fields)}

      @type option :: unquote(union_type(option_variants))
    end
  end

  defp prop_type_ast({name, Plushie.Type.Color, _opts}) do
    {name, quote(do: Plushie.Type.Color.t() | nil)}
  end

  defp prop_type_ast({name, type, _opts}) do
    {name, quote(do: unquote(elixir_type_for(type)) | nil)}
  end

  defp elixir_type_for(type) do
    case Plushie.Type.resolve(type) do
      {:composite, {:list, inner}} ->
        quote(do: [unquote(elixir_type_for(inner))])

      {:composite, _} ->
        quote(do: term())

      module ->
        module.typespec()
    end
  end

  # Option types use broader input types for cast-based types (e.g. Color
  # accepts atoms, hex strings, maps). For other types the option and
  # storage types are the same.
  defp option_type_for(Plushie.Type.Color), do: quote(do: Plushie.Type.Color.input())

  defp option_type_for(type), do: elixir_type_for(type)

  defp union_type([single]), do: single

  defp union_type([head | tail]) do
    Enum.reduce(tail, head, fn variant, acc ->
      quote(do: unquote(acc) | unquote(variant))
    end)
  end

  defp generate_struct_new(container, positional, props)

  defp generate_struct_new(container, [], _props) do
    doc = "Creates a new widget struct with the given ID and keyword options."

    if container do
      quote do
        @doc unquote(doc)
        @spec new(id :: String.t(), opts :: [option()]) :: t()
        def new(id, opts \\ []) when is_binary(id) do
          {children, opts} = Keyword.pop(opts, :do, [])
          widget = %__MODULE__{id: id} |> with_options(opts)
          %{widget | children: List.wrap(children)}
        end
      end
    else
      quote do
        @doc unquote(doc)
        @spec new(id :: String.t(), opts :: [option()]) :: t()
        def new(id, opts \\ []) when is_binary(id) do
          %__MODULE__{id: id} |> with_options(opts)
        end
      end
    end
  end

  defp generate_struct_new(_container, positional, props) do
    # Use Macro.var with __MODULE__ context so all references within the
    # generated quote block share the same hygiene context.
    ctx = __MODULE__
    id_var = Macro.var(:id, ctx)
    opts_var = Macro.var(:opts, ctx)

    positional_vars = Enum.map(positional, fn name -> Macro.var(name, ctx) end)

    # Build struct init map: %{id: id, pos1: pos1, pos2: pos2}
    struct_pairs =
      [{:id, id_var} | Enum.map(positional, fn name -> {name, Macro.var(name, ctx)} end)]

    # Build guards for positional args based on their prop types.
    # Positional fields with a default are optional and accept nil.
    positional_guards =
      for name <- positional,
          {^name, type, opts} <- props,
          guard_fn = positional_guard(type) do
        var = Macro.var(name, ctx)
        base = guard_fn.(var)
        has_default = Keyword.has_key?(opts, :default)

        if has_default do
          quote(do: unquote(base) or is_nil(unquote(var)))
        else
          base
        end
      end

    base_guard = quote(do: is_binary(unquote(id_var)))

    full_guard =
      Enum.reduce(positional_guards, base_guard, fn guard, acc ->
        quote(do: unquote(acc) and unquote(guard))
      end)

    args_with_default = positional_vars ++ [{:\\, [], [opts_var, []]}]

    struct_kw = Enum.map(struct_pairs, fn {k, v} -> {k, v} end)

    body =
      quote do
        struct!(__MODULE__, unquote(struct_kw)) |> with_options(unquote(opts_var))
      end

    # Build a proper constructor doc with positional argument descriptions
    arg_lines =
      Enum.map(positional, fn name ->
        case Enum.find(props, fn {n, _, _} -> n == name end) do
          {_, _type, opts} ->
            desc = Keyword.get(opts, :doc, "")
            if desc != "", do: "- `#{name}` - #{desc}", else: "- `#{name}`"

          nil ->
            "- `#{name}`"
        end
      end)

    doc =
      [
        "Creates a new widget struct with the given positional args and keyword options.",
        "",
        "## Arguments",
        "",
        "- `id` - unique widget identifier"
        | arg_lines
      ]
      |> Kernel.++(["- `opts` - keyword list of optional props"])
      |> Enum.join("\n")

    quote do
      @doc unquote(doc)
      def new(unquote(id_var), unquote_splicing(args_with_default))
          when unquote(full_guard) do
        unquote(body)
      end
    end
  end

  defp positional_guard(type) do
    case Plushie.Type.resolve(type) do
      {:composite, {:list, _}} ->
        fn var -> quote(do: is_list(unquote(var))) end

      {:composite, {:map, _}} ->
        fn var -> quote(do: is_map(unquote(var)) or is_list(unquote(var))) end

      {:composite, {:tuple, types}} ->
        len = length(types)

        fn var ->
          quote(do: is_tuple(unquote(var)) and tuple_size(unquote(var)) == unquote(len))
        end

      {:composite, {:enum, values}} ->
        escaped = Macro.escape(values)
        fn var -> quote(do: unquote(var) in unquote(escaped)) end

      {:composite, _} ->
        nil

      module ->
        if function_exported?(module, :guard, 1) do
          fn var -> module.guard(var) end
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

    all_clauses = prop_clauses ++ [unknown_clause]
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
      @doc false
      def from_opts(opts), do: with_options(%__MODULE__{id: Keyword.fetch!(opts, :id)}, opts)

      @doc false
      def __field_keys__, do: unquote(prop_names)

      @doc false
      def __field_types__, do: unquote(Macro.escape(field_types_map))
    end
  end

  defp generate_setters(props, positional) do
    prop_setters =
      Enum.map(props, fn {name, type, opts} ->
        type_str = type_display_string(type)

        doc =
          case Keyword.get(opts, :doc) do
            nil ->
              "Sets the `#{name}` field. Accepts `#{type_str}`."

            desc ->
              "#{desc}\n\nAccepts `#{type_str}`."
          end

        cast_fn = Keyword.get(opts, :cast)

        encoder = encoder_for_type(type)
        value_type = elixir_type_for(type)
        constraint_opts = Keyword.drop(opts, @known_field_opts)
        base_guard = setter_guard(type)
        guard = combine_guard(base_guard, constraint_guard(type, constraint_opts))

        # A field is "required" if it's positional with no default.
        # Required fields do not get a nil setter clause.
        has_default = Keyword.has_key?(opts, :default)
        is_positional = name in positional
        is_required = is_positional and not has_default
        wants_nil_clause = not is_required

        nil_clause =
          if wants_nil_clause do
            quote do
              def unquote(name)(%__MODULE__{} = widget, nil),
                do: %{widget | unquote(name) => nil}
            end
          end

        merge = Keyword.get(opts, :merge, false)

        setter_clause =
          if merge do
            generate_merge_setter_clause(name, type, doc, value_type)
          else
            generate_setter_clause(
              name,
              doc,
              value_type,
              wants_nil_clause,
              cast_fn,
              guard,
              encoder
            )
          end

        if nil_clause do
          quote do
            unquote(nil_clause)
            unquote(setter_clause)
          end
        else
          setter_clause
        end
      end)

    prop_setters
  end

  # Generates the value-accepting clause of a setter (the non-nil branch).
  defp generate_setter_clause(name, doc, value_type, _wants_nil, cast_fn, _guard, _encoder)
       when cast_fn != nil do
    escaped_cast = Macro.escape(cast_fn)

    quote do
      @doc unquote(doc)
      @spec unquote(name)(widget :: t(), value :: unquote(value_type) | nil) :: t()
      def unquote(name)(%__MODULE__{} = widget, value) do
        %{widget | unquote(name) => unquote(escaped_cast).(value)}
      end
    end
  end

  defp generate_setter_clause(name, doc, value_type, _wants_nil, _cast_fn, nil = _guard, encoder) do
    quote do
      @doc unquote(doc)
      @spec unquote(name)(widget :: t(), value :: unquote(value_type) | nil) :: t()
      def unquote(name)(%__MODULE__{} = widget, value) do
        %{widget | unquote(name) => unquote(encoder).(value)}
      end
    end
  end

  defp generate_setter_clause(name, doc, value_type, wants_nil, _cast_fn, guard, encoder) do
    spec_type =
      if wants_nil do
        quote(do: unquote(value_type) | nil)
      else
        value_type
      end

    quote do
      @doc unquote(doc)
      @spec unquote(name)(widget :: t(), value :: unquote(spec_type)) :: t()
      def unquote(name)(%__MODULE__{} = widget, value) when unquote(guard) do
        %{widget | unquote(name) => unquote(encoder).(value)}
      end
    end
  end

  # Generates a setter that casts the value and merges with the existing
  # field value when present. Used for types like A11y where user-provided
  # values should overlay widget defaults rather than replace them.
  defp generate_merge_setter_clause(name, type, doc, value_type) do
    type_module =
      case Plushie.Type.resolve(type) do
        {:composite, _} ->
          raise CompileError,
            description:
              "merge: true is not supported for composite types (field #{inspect(name)})"

        module ->
          module
      end

    quote do
      @doc unquote(doc)
      @spec unquote(name)(widget :: t(), value :: unquote(value_type) | nil) :: t()
      def unquote(name)(%__MODULE__{} = widget, value) do
        {:ok, casted} = unquote(type_module).cast(value)

        merged =
          case Map.get(widget, unquote(name)) do
            nil -> casted
            existing -> Plushie.Type.merge_value(unquote(type_module), existing, casted)
          end

        %{widget | unquote(name) => merged}
      end
    end
  end

  defp setter_guard(type) do
    case Plushie.Type.resolve(type) do
      {:composite, {:list, _}} ->
        quote(do: is_list(value))

      {:composite, {:map, _}} ->
        quote(do: is_map(value) or is_list(value))

      {:composite, {:tuple, types}} ->
        len = length(types)
        quote(do: is_tuple(value) and tuple_size(value) == unquote(len))

      {:composite, {:enum, values}} ->
        quote(do: value in unquote(Macro.escape(values)))

      {:composite, _} ->
        nil

      module ->
        Code.ensure_compiled(module)

        # Types with cast/1 use the cast as the sole validator.
        # Guards are only used for types without cast (which rely
        # on the guard to reject invalid inputs).
        if not function_exported?(module, :cast, 1) and function_exported?(module, :guard, 1) do
          module.guard(quote(do: value))
        end
    end
  end

  # Extracts constraint guards from a type module's constrain_guard/2 callback.
  defp constraint_guard(_type, []), do: []

  defp constraint_guard(type, constraint_opts) do
    case Plushie.Type.resolve(type) do
      {:composite, _} ->
        []

      module ->
        Code.ensure_compiled(module)

        if function_exported?(module, :constrain_guard, 2) do
          module.constrain_guard(quote(do: value), constraint_opts)
        else
          []
        end
    end
  end

  # Combines a base guard with a list of additional constraint guards.
  defp combine_guard(base, []), do: base

  defp combine_guard(nil, constraints) do
    Enum.reduce(constraints, fn right, left ->
      quote(do: unquote(left) and unquote(right))
    end)
  end

  defp combine_guard(base, constraints) do
    Enum.reduce(constraints, base, fn right, left ->
      quote(do: unquote(left) and unquote(right))
    end)
  end

  defp generate_build(:single) do
    quote do
      @doc "Converts this widget struct to a `ui_node()` map. Validates at most one child."
      @spec build(widget :: t()) :: Plushie.Widget.ui_node()
      def build(%__MODULE__{children: []} = widget), do: Plushie.Widget.to_node(widget)
      def build(%__MODULE__{children: [_]} = widget), do: Plushie.Widget.to_node(widget)

      def build(%__MODULE__{children: children}) do
        raise ArgumentError,
              "#{inspect(__MODULE__)} accepts at most 1 child, got #{length(children)}"
      end
    end
  end

  defp generate_build(_container) do
    quote do
      @doc "Converts this widget struct to a `ui_node()` map."
      @spec build(widget :: t()) :: Plushie.Widget.ui_node()
      def build(%__MODULE__{} = widget), do: Plushie.Widget.to_node(widget)
    end
  end

  defp generate_container_helpers do
    quote do
      @doc "Appends a child to the widget."
      @spec push(widget :: t(), child :: Plushie.Widget.child()) :: t()
      def push(%__MODULE__{} = widget, child),
        do: %{widget | children: [child | widget.children]}

      @doc "Appends multiple children to the widget."
      @spec extend(widget :: t(), children :: [Plushie.Widget.child()]) :: t()
      def extend(%__MODULE__{} = widget, children),
        do: %{widget | children: Enum.reverse(children) ++ widget.children}
    end
  end

  defp generate_widget_protocol(
         _module,
         kind,
         widget_type,
         type_string,
         container,
         props,
         events,
         event_specs
       ) do
    put_calls =
      Enum.map(props, fn {name, type, opts} ->
        wire_key = Keyword.get(opts, :wire_name, name)

        # Color needs casting in to_node because struct defaults bypass setters.
        # All other types store raw values -- Tree.normalize handles encoding.
        if type == Plushie.Type.Color do
          quote do
            props =
              Plushie.Widget.Build.put_if(
                props,
                widget.unquote(name),
                unquote(wire_key),
                fn val ->
                  {:ok, casted} = Plushie.Type.Color.cast(val)
                  casted
                end
              )
          end
        else
          quote do
            props =
              Plushie.Widget.Build.put_if(
                props,
                widget.unquote(name),
                unquote(wire_key)
              )
          end
        end
      end)

    children =
      if container do
        # Children are stored in reverse order via push/extend.
        # Reverse before converting to nodes to restore insertion order.
        quote(do: Plushie.Widget.Build.children_to_nodes(Enum.reverse(widget.children)))
      else
        quote(do: [])
      end

    # Native widgets attach Meta.Native for event dispatch registration.
    # Built-in widgets (kind == :widget without view) don't need metadata.
    meta_put =
      if kind == :native_widget do
        quote do
          props =
            Map.put(props, :__widget__, %Plushie.Widget.Meta.Native{
              type: unquote(widget_type),
              events: unquote(events),
              event_specs: unquote(Macro.escape(event_specs))
            })
        end
      end

    # defimpl must be defined at the top level of the module, not inside a
    # function. We generate the AST here; it's injected via __before_compile__.
    quote do
      defimpl Plushie.Widget.WidgetProtocol do
        def to_node(widget) do
          props = %{}
          unquote_splicing(put_calls)
          unquote(meta_put)
          props = Plushie.Widget.Build.resolve_a11y(props)

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
      Enum.map(props, fn {name, _type, _opts} -> name end)

    quote do
      unknown_keys = Keyword.keys(opts) -- unquote(known_names)

      if unknown_keys != [] do
        raise ArgumentError,
              "unknown option(s) #{inspect(unknown_keys)} for #{inspect(__MODULE__)}.new"
      end
    end
  end

  defp encoder_for_type(type) do
    case Plushie.Type.resolve(type) do
      {:composite, composite} -> composite_encoder(composite)
      module -> module_encoder(module)
    end
  end

  defp composite_encoder(composite) do
    escaped = Macro.escape(composite)

    quote do
      fn val ->
        case Plushie.Type.cast_composite(unquote(escaped), val) do
          {:ok, casted} -> casted
          :error -> raise ArgumentError, "cast failed for value: #{inspect(val)}"
        end
      end
    end
  end

  defp module_encoder(module) do
    Code.ensure_compiled(module)

    cond do
      module == Plushie.Type.Any ->
        quote(do: fn val -> val end)

      function_exported?(module, :cast, 1) ->
        cast_encoder(module)

      true ->
        quote(do: fn val -> val end)
    end
  end

  defp cast_encoder(module) do
    quote do
      fn val ->
        case unquote(module).cast(val) do
          {:ok, casted} -> casted
          :error -> raise ArgumentError, "cast failed for value: #{inspect(val)}"
        end
      end
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

  defp guard_for_type(var, type) do
    case Plushie.Type.resolve(type) do
      {:composite, {:list, _}} ->
        quote(do: is_list(unquote(var)))

      {:composite, {:map, _}} ->
        quote(do: is_map(unquote(var)) or is_list(unquote(var)))

      {:composite, _} ->
        quote(do: true)

      module ->
        if function_exported?(module, :guard, 1) do
          module.guard(var) || quote(do: true)
        else
          quote(do: true)
        end
    end
  end

  # Build a simple AST variable reference from an atom name.
  defp to_var(name) when is_atom(name), do: {name, [], nil}
end
