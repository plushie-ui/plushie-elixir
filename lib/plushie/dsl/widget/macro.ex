defmodule Plushie.DSL.Widget.Macro do
  @moduledoc false

  # DSL macros for widget declarations.
  #
  # These macros are imported into modules that `use Plushie.Widget` and
  # accumulate module attributes consumed by `__before_compile__`.

  # -- widget/1..3 -------------------------------------------------------------

  @doc """
  Declares the widget type name. Pass `container: true` for container widgets.

  Accepts an optional do-block for grouping field and positional declarations:

      widget :checkbox do
        field :label, :string, doc: "Text label."
        field :is_toggled, :boolean, option: false, doc: "Checked state."
        positional [:label, :is_toggled]
      end

  Without a block, declares the type name only (e.g. `widget :space`).

  ## Container widgets

  Pass `container: true` to declare a widget that holds children:

      widget :panel, container: true do
        field :direction, :atom, default: :vertical
      end

  This generates:

  - A `:children` field on the struct (defaults to `[]`)
  - `push/2` to append a single child
  - `extend/2` to append multiple children
  - `new/2` accepts a do-block for children

  Example usage:

      Panel.new("main", direction: :horizontal) do
        text("greeting", "Hello")
        button("ok", "OK")
      end
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

  # -- positional/1 ------------------------------------------------------------

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

  # -- event/1..2 --------------------------------------------------------------

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
  `:boolean`, `:any`) or modules implementing `Plushie.Type`.
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

  # -- state/1 -----------------------------------------------------------------

  @doc """
  Declares internal state fields for a stateful widget.

  State is persistent internal data that survives across renders
  but is never sent to the renderer. It is owned by the runtime
  and scoped to each widget instance. Use it for interaction
  tracking (hover, drag, selection) that the app model should
  not need to know about.

  Declaring any state fields makes the widget stateful: the view
  is deferred to tree normalization and the `WidgetHandler`
  behaviour is injected automatically.

  ## Lifecycle

  1. `__initial_state__/0` returns the default state map (generated
     from your declarations).
  2. The runtime stores per-instance state keyed by widget ID.
  3. `view/3` receives `(id, props, state)` where `state` is the
     current state map for this instance.
  4. `handle_event/2` can return `{:update_state, new_state}` to
     modify state without emitting an event to the app.

  ## Keyword form (untyped)

      state hover: nil, drag: :none

  ## Block form (typed)

      state do
        field :hover, :boolean, default: false
        field :drag, :atom, default: :none
      end

  ## Example

      defmodule HoverButton do
        use Plushie.Widget

        widget :hover_button do
          field :label, :string
        end

        state do
          field :hovered, :boolean, default: false
        end

        def view(id, props, state) do
          color = if state.hovered, do: :blue, else: :gray
          button(id, props.label, style: [background: color])
        end

        def handle_event(%WidgetEvent{family: :mouse_enter}, state) do
          {:update_state, %{state | hovered: true}}
        end

        def handle_event(%WidgetEvent{family: :mouse_leave}, state) do
          {:update_state, %{state | hovered: false}}
        end

        def handle_event(_event, _state), do: :ignored
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

  # -- cache_key/1 -------------------------------------------------------------

  @doc """
  Declares an optional cache key function for expensive widgets.

  When declared, the normalizer calls this function before `view/3`.
  If the returned key matches the previous render's key, the cached
  normalized output is reused and `view/3` is skipped entirely.
  This avoids re-running the view function and re-normalizing the
  subtree, which matters for widgets that produce large or
  computationally expensive trees.

  The function receives two arguments: the full props map and the
  current state map (or `nil` for stateless widgets). Return any
  term that can be compared with `==`.

      cache_key fn props, state ->
        {props.data_version, state.zoom_level}
      end

  A common pattern is to derive the key from the specific props
  that affect the output:

      cache_key fn props, _state ->
        {props.items, props.filter}
      end

  Only applicable to `:widget` kind (not `:native_widget`).
  """
  defmacro cache_key(fun) do
    escaped = Macro.escape(fun)

    quote do
      @_widget_cache_key_fn unquote(escaped)
    end
  end

  # -- field/2..3 --------------------------------------------------------------

  @doc """
  Declares a typed field on the widget.

  At the widget level, accumulates into `@_widget_props`:

      field :value, :float
      field :color, Plushie.Type.Color, default: :blue

  Inside an `event` do-block, `field` calls are consumed as AST by the
  event macro and parsed into the event spec. They are never expanded
  as macros in that context.

  ## Options

  - `default:` - default value for the struct field. When omitted,
    defaults to `nil`.
  - `doc:` - description used in auto-generated moduledoc tables and
    setter function docs.
  - `option:` - when `false`, the field is excluded from keyword
    options (`with_options/2`, `__field_keys__/0`) but still
    generates a struct field and setter. Default `true`. Typically
    used with `positional` for fields that should only be set
    positionally.
  - `wire_name:` - override the key name sent to the renderer. The
    Elixir-side field keeps its declared name; only the wire
    representation changes. Useful when the renderer expects a
    different naming convention.
  - `cast:` - custom cast function (1-arity) that overrides the
    type's built-in cast. Receives the raw value, should return
    `{:ok, casted}` or `:error`.
  - `merge:` - when `true`, the setter merges the new value with
    the existing value (via `Map.merge/2`) instead of replacing it.
    Useful for map-typed fields where callers set partial updates.
    Default `false`.
  """
  defmacro field(name, type, opts \\ []) do
    quote do
      @_widget_props {unquote(name), unquote(type), unquote(opts)}
    end
  end

  # -- command/1..2 ------------------------------------------------------------

  @doc """
  Declares a command that the renderer can execute (native_widget only).

  Commands generate a public function that builds a `Plushie.Command`
  targeting a specific widget instance by ID. The renderer receives
  the command and routes it to the widget's `handle_widget_op`
  implementation on the Rust side.

  Supports the same forms as `event`:

  ## No payload

      command :reset

  ## Typed value

      command :set_value, value: :float

  ## Structured fields

      command :set_range, fields: [min: :float, max: :float]

  ## Block form

      command :configure do
        field :min, :float
        field :max, :float
        field :step, :float, required: false
      end

  Required fields become positional args. Optional fields become
  keyword opts. Values are encoded through `Plushie.Type.encode_value`.
  """
  defmacro command(name, opts_or_block \\ [])

  defmacro command(name, do: block) do
    caller = __CALLER__
    validate_event_name!(name, caller)
    block = expand_type_aliases_in_ast(block, caller)
    spec = parse_event_block(block, caller)
    validate_event_spec!(name, spec, caller)

    quote bind_quoted: [name: name, spec: Macro.escape(spec)] do
      @_widget_commands {name, spec}
    end
  end

  defmacro command(name, opts) do
    caller = __CALLER__
    validate_event_name!(name, caller)
    opts = expand_type_aliases(opts, caller)
    spec = parse_event_opts(opts, caller)
    validate_event_spec!(name, spec, caller)

    quote bind_quoted: [name: name, spec: Macro.escape(spec)] do
      @_widget_commands {name, spec}
    end
  end

  # -- rust_crate/1, rust_constructor/1 ----------------------------------------

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

  # -- Helpers (called from macros above) --------------------------------------

  @doc false
  def validate_widget_type_name!(type_name, caller) do
    unless is_atom(type_name) do
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description: "widget type name must be an atom, got: #{inspect(type_name)}"
    end
  end

  @doc false
  def validate_state_field_type!(name, type, caller) do
    unless Plushie.DSL.Validation.valid_type?(type) do
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description:
          "unsupported state field type #{inspect(type)} for field #{inspect(name)}. " <>
            "Use a primitive shortcut (:string, :float, etc.) or a Plushie.Type module."
    end
  end

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

  # -- Private helpers ---------------------------------------------------------

  defp maybe_expand_alias({:__aliases__, _, _} = ast, caller) do
    Macro.expand(ast, caller)
  end

  defp maybe_expand_alias(other, _caller), do: other

  # Parses a list of `field` statements into a data spec with required tracking.
  defp parse_data_block_to_spec(stmts, caller) do
    {fields, required} = parse_data_stmts(stmts, caller)
    %{carrier: :value, fields: fields, required: required}
  end

  @doc false
  def block_to_list({:__block__, _, stmts}), do: stmts
  def block_to_list(stmt), do: [stmt]

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
            "Use a built-in type (:float, :string, :boolean, :any) or a module implementing Plushie.Type."
    end
  end
end
