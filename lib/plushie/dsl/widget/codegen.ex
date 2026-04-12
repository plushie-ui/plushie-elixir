defmodule Plushie.DSL.Widget.Codegen do
  @moduledoc false

  # Widget-specific code generation for widget declarations.
  #
  # Shared field infrastructure (structs, setters, type utilities)
  # lives in `Plushie.DSL.Fields`. This module handles widget-specific
  # concerns: protocol impl, events, state, commands, handler behaviour.
  #
  # All `generate_*` functions produce quoted AST that is spliced into
  # the widget module by `Plushie.Widget.__before_compile__/1`.

  alias Plushie.DSL.Fields

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

  # -- Delegated to Plushie.DSL.Fields -----------------------------------------

  defdelegate generate_prop_names(props), to: Fields
  defdelegate generate_prop_validation(props), to: Fields

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

    struct_def = Fields.generate_struct_and_types(props, container)
    new_fn = Fields.generate_struct_new(container, positional, props)
    with_options_fn = Fields.generate_with_options(option_props)
    setters = Fields.generate_setters(props, positional)
    dsl_fns = Fields.generate_dsl_buildable(option_props)
    build_fn = Fields.generate_build(container)
    container_fns = if container, do: Fields.generate_container_helpers(), else: nil

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

      defimpl Plushie.Tree.Node do
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
      def new(id, var!(opts) \\ []) when is_binary(id) do
        prop_defaults = unquote(Macro.escape(prop_struct_fields))
        unquote(prop_extract)

        props_map =
          prop_defaults
          |> Enum.map(fn {name, default} ->
            {name, Keyword.get(var!(opts), name, default)}
          end)
          |> Enum.reject(fn {_name, val} -> is_nil(val) end)
          |> Map.new()

        struct!(__MODULE__, Map.put(props_map, :id, id))
      end
    end
  end

  # -- Commands ----------------------------------------------------------------

  @doc false
  def generate_commands(commands) do
    fns = Enum.map(commands, &generate_command_fn/1)

    quote do
      (unquote_splicing(fns))
    end
  end

  defp generate_command_fn({name, %{carrier: :none}}) do
    family = Atom.to_string(name)

    quote do
      @doc "Sends the `#{unquote(family)}` command to the widget."
      @spec unquote(name)(String.t()) :: Plushie.Command.t()
      def unquote(name)(widget_id) when is_binary(widget_id) do
        Plushie.Command.widget_command(widget_id, unquote(family))
      end
    end
  end

  defp generate_command_fn({name, %{carrier: :value, type: type}}) do
    family = Atom.to_string(name)
    val_var = Macro.var(:value, __MODULE__)
    guard = guard_for_type(val_var, type)
    type_ast = Fields.castable_type_for(type)

    quote do
      @doc "Sends the `#{unquote(family)}` command to the widget."
      @spec unquote(name)(String.t(), unquote(type_ast)) :: Plushie.Command.t()
      def unquote(name)(widget_id, unquote(val_var))
          when is_binary(widget_id) and unquote(guard) do
        Plushie.Command.widget_command(
          widget_id,
          unquote(family),
          Plushie.Type.encode_value(unquote(val_var))
        )
      end
    end
  end

  defp generate_command_fn({name, %{carrier: :value, fields: fields} = spec}) do
    family = Atom.to_string(name)
    required = Map.get(spec, :required, Keyword.keys(fields))
    optional = Keyword.keys(fields) -- required

    # Required fields become positional args
    req_args = Enum.map(required, &to_var/1)
    # Build guards for required args
    req_guards = build_field_guards(fields, required)

    # Build the payload map from required args
    req_pairs =
      Enum.map(required, fn field_name ->
        {field_name, quote(do: Plushie.Type.encode_value(unquote(to_var(field_name))))}
      end)

    # Build @spec param types
    req_types = Enum.map(required, fn f -> Fields.castable_type_for(fields[f]) end)

    all_args = [quote(do: widget_id) | req_args]
    all_spec_types = [quote(do: String.t()) | req_types]

    base_guard =
      case req_guards do
        {true, _, _} ->
          quote(do: is_binary(widget_id))

        _ ->
          quote(do: is_binary(widget_id) and unquote(req_guards))
      end

    if optional == [] do
      # All fields required, no keyword opts
      payload = {:%{}, [], req_pairs}

      quote do
        @doc "Sends the `#{unquote(family)}` command to the widget."
        @spec unquote(name)(unquote_splicing(all_spec_types)) :: Plushie.Command.t()
        def unquote(name)(unquote_splicing(all_args)) when unquote(base_guard) do
          Plushie.Command.widget_command(
            widget_id,
            unquote(family),
            unquote(payload)
          )
        end
      end
    else
      # Has optional fields: add opts keyword arg
      opt_names = Macro.escape(optional)
      payload = {:%{}, [], req_pairs}

      quote do
        @doc "Sends the `#{unquote(family)}` command to the widget."
        @spec unquote(name)(unquote_splicing(all_spec_types), keyword()) :: Plushie.Command.t()
        def unquote(name)(unquote_splicing(all_args), opts \\ []) when unquote(base_guard) do
          base = unquote(payload)

          value =
            Enum.reduce(opts, base, fn {k, v}, acc ->
              if k in unquote(opt_names) do
                Map.put(acc, k, Plushie.Type.encode_value(v))
              else
                raise ArgumentError,
                      "unknown option #{inspect(k)} for command #{unquote(family)}"
              end
            end)

          Plushie.Command.widget_command(widget_id, unquote(family), value)
        end
      end
    end
  end

  # -- Private helpers ---------------------------------------------------------

  # Widget participates in event dispatch if it declares events,
  # has state fields, or defines handle_event/2 explicitly.
  defp participates_in_dispatch?(has_handle_event, events, state_fields) do
    has_handle_event or events != [] or state_fields != []
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
    put_calls = Fields.generate_prop_put_calls(props)

    children =
      if container do
        # Children are stored in reverse order via push/extend.
        # Reverse before converting to nodes to restore insertion order.
        quote(do: Plushie.Widget.Build.children_to_nodes(Enum.reverse(var!(widget).children)))
      else
        quote(do: [])
      end

    # Native widgets attach Meta.Native for event dispatch registration.
    # Built-in widgets (kind == :widget without view) don't need metadata.
    meta_put =
      if kind == :native_widget do
        quote do
          var!(props) =
            Map.put(var!(props), :__widget__, %Plushie.Widget.Meta.Native{
              type: unquote(widget_type),
              events: unquote(events),
              event_specs: unquote(Macro.escape(event_specs))
            })
        end
      end

    # defimpl must be defined at the top level of the module, not inside a
    # function. We generate the AST here; it's injected via __before_compile__.
    quote do
      defimpl Plushie.Tree.Node do
        def to_node(var!(widget)) do
          var!(props) = %{}
          unquote_splicing(put_calls)
          unquote(meta_put)
          var!(props) = Plushie.Widget.Build.resolve_a11y(var!(props))

          %{
            id: var!(widget).id,
            type: unquote(type_string),
            props: var!(props),
            children: unquote(children)
          }
        end
      end
    end
  end

  defp build_field_guards(fields, names) do
    guards =
      names
      |> Enum.map(fn field_name ->
        type = fields[field_name]
        guard_for_type(to_var(field_name), type)
      end)
      |> Enum.reject(&match?({true, _, _}, &1))

    case guards do
      [] ->
        quote(do: true)

      [single] ->
        single

      multiple ->
        Enum.reduce(multiple, fn right, left -> quote(do: unquote(left) and unquote(right)) end)
    end
  end

  defp guard_for_type(var, type) do
    Fields.type_guard_ast(type, var) || quote(do: true)
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
      Enum.map(commands, fn {name, spec} ->
        type_str = event_spec_display(spec) |> escape_table_pipes()
        "| `:#{name}` | #{type_str} |"
      end)

    header =
      "## Commands\n\n" <>
        "| Command | Type |\n" <>
        "|---------|------|"

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
