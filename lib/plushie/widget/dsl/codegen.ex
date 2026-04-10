defmodule Plushie.Widget.DSL.Codegen do
  @moduledoc false

  # Code generation for widget declarations.
  #
  # All `generate_*` functions produce quoted AST that is spliced into
  # the widget module by `Plushie.Widget.__before_compile__/1`.

  @known_field_opts Plushie.Widget.DSL.Validation.known_field_opts()

  @known_type_mappings %{
    a11y: Plushie.Type.A11y,
    padding: Plushie.Type.Padding,
    style: Plushie.Type.StyleMap,
    border: Plushie.Type.Border,
    shadow: Plushie.Type.Shadow,
    font: Plushie.Type.Font
  }

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

  # -- Moduledoc generation ----------------------------------------------------

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

  # -- Behaviour functions -----------------------------------------------------

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

  # -- Widget info -------------------------------------------------------------

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

  # -- Cache key ---------------------------------------------------------------

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

  # -- Prop names --------------------------------------------------------------

  @doc false
  def generate_prop_names(props) do
    known =
      Enum.map(props, fn {name, _type, _opts} -> name end)

    quote do
      @doc false
      def __prop_names__, do: unquote(known)
    end
  end

  # -- Struct-based widget generation ------------------------------------------
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

  # -- Stateful widget generation (view/2 or view/3) ---------------------------

  @doc false
  def generate_widget_new(
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
      pipeline: struct -> to_node -> normalize. The widget is rendered
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

  # -- Prop validation ---------------------------------------------------------

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

  # -- Commands ----------------------------------------------------------------

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

  # -- Private helpers ---------------------------------------------------------

  # Widget participates in event dispatch if it declares events,
  # has state fields, or defines handle_event/2 explicitly.
  defp participates_in_dispatch?(has_handle_event, events, state_fields) do
    has_handle_event or events != [] or state_fields != []
  end

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

  defp prop_type_ast({name, type, _opts}) do
    {name, quote(do: unquote(elixir_type_for(type)) | nil)}
  end

  defp elixir_type_for(type) do
    case Plushie.Type.resolve(type) do
      {:composite, {kind, spec}} ->
        Plushie.Type.composite_module(kind).typespec(spec, &elixir_type_for/1)

      module ->
        module.typespec()
    end
  end

  defp castable_type_for(type) do
    case Plushie.Type.resolve(type) do
      {:composite, {kind, spec}} ->
        mod = Plushie.Type.composite_module(kind)

        if function_exported?(mod, :castable, 2) do
          mod.castable(spec, &castable_type_for/1)
        else
          mod.typespec(spec, &castable_type_for/1)
        end

      module ->
        module.castable()
    end
  end

  defp option_type_for(type), do: castable_type_for(type)

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
    case type_guard_ast(type, quote(do: __placeholder__)) do
      nil -> nil
      _guard -> fn var -> type_guard_ast(type, var) end
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
        type_str = Plushie.Type.type_display_string(type)

        doc =
          case Keyword.get(opts, :doc) do
            nil ->
              "Sets the `#{name}` field. Accepts `#{type_str}`."

            desc ->
              "#{desc}\n\nAccepts `#{type_str}`."
          end

        cast_fn = Keyword.get(opts, :cast)

        encoder = encoder_for_type(type)
        value_type = castable_type_for(type)
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

  # Single source of truth for extracting a guard AST from a type.
  # Returns the guard expression or nil when the type has no guard.
  defp type_guard_ast(type, var) do
    case Plushie.Type.resolve(type) do
      {:composite, {kind, spec}} ->
        Plushie.Type.composite_module(kind).guard(spec, var)

      module ->
        Code.ensure_compiled(module)

        if function_exported?(module, :guard, 1) do
          module.guard(var)
        end
    end
  end

  defp setter_guard(type) do
    case Plushie.Type.resolve(type) do
      # Types with cast/1 use the cast as the sole validator.
      # Guards are only used for types without cast (which rely
      # on the guard to reject invalid inputs).
      module when is_atom(module) ->
        Code.ensure_compiled(module)

        if function_exported?(module, :cast, 1) do
          nil
        else
          type_guard_ast(type, quote(do: value))
        end

      _ ->
        type_guard_ast(type, quote(do: value))
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

  # Generates the list of quoted `put_if` expressions that populate the
  # props map inside a WidgetProtocol.to_node/1 implementation.
  defp generate_prop_put_calls(props) do
    Enum.map(props, fn {name, type, opts} ->
      wire_key = Keyword.get(opts, :wire_name, name)

      # Color needs casting in to_node because struct defaults bypass setters.
      # All other types store raw values: Tree.normalize handles encoding.
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
    put_calls = generate_prop_put_calls(props)

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

  defp build_command_spec(name, params) do
    param_types = [
      quote(do: String.t()) | Enum.map(params, fn {_n, t} -> castable_type_for(t) end)
    ]

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
    type_guard_ast(type, var) || quote(do: true)
  end

  # Build a simple AST variable reference from an atom name.
  defp to_var(name) when is_atom(name), do: {name, [], nil}

  # -- Moduledoc section helpers -----------------------------------------------

  defp generate_props_section([], _positional), do: nil

  defp generate_props_section(props, positional) do
    rows =
      Enum.map(props, fn {name, type, opts} ->
        type_str = Plushie.Type.type_display_string(type) |> escape_table_pipes()
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
          type_str = Plushie.Type.type_display_string(type) |> escape_table_pipes()
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
              "`#{pname}: #{Plushie.Type.type_display_string(ptype)}`"
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
    "`value: #{Plushie.Type.type_display_string(type)}`"
  end

  defp event_spec_display(%{carrier: :value, fields: fields}) do
    fields_str =
      Enum.map_join(fields, ", ", fn {name, type} ->
        "#{name}: #{Plushie.Type.type_display_string(type)}"
      end)

    "`value: %{#{fields_str}}`"
  end

  # Escape pipe characters inside markdown table cells so that ExDoc does not
  # split on them. Uses the HTML entity which renders as a literal pipe.
  defp escape_table_pipes(str), do: String.replace(str, "|", "\\|")
end
