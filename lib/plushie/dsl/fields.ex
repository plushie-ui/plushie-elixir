defmodule Plushie.DSL.Fields do
  @moduledoc false

  # Shared field infrastructure for struct-based DSL modules.
  #
  # Extracted from Plushie.DSL.Widget.Codegen. Generates struct
  # definitions, constructors, setters, type utilities, and field
  # introspection. Reusable by widgets, canvas elements, and any
  # future struct-based DSL.

  @known_field_opts Plushie.DSL.Validation.known_field_opts()

  @known_type_mappings %{
    a11y: Plushie.Type.A11y,
    padding: Plushie.Type.Padding,
    style: Plushie.Type.StyleMap,
    border: Plushie.Type.Border,
    shadow: Plushie.Type.Shadow,
    font: Plushie.Type.Font
  }

  # -- Struct and type generation ----------------------------------------------

  @doc false
  def generate_struct_and_types(props, container) do
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

  @doc false
  def prop_type_ast({name, type, _opts}) do
    {name, quote(do: unquote(elixir_type_for(type)) | nil)}
  end

  # -- Type utilities ----------------------------------------------------------

  @doc false
  def elixir_type_for(type) do
    case Plushie.Type.resolve(type) do
      {:composite, {kind, spec}} ->
        Plushie.Type.composite_module(kind).typespec(spec, &elixir_type_for/1)

      module ->
        module.typespec()
    end
  end

  @doc false
  def castable_type_for(type) do
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

  @doc false
  def option_type_for(type), do: castable_type_for(type)

  @doc false
  def union_type([single]), do: single

  def union_type([head | tail]) do
    Enum.reduce(tail, head, fn variant, acc ->
      quote(do: unquote(acc) | unquote(variant))
    end)
  end

  # -- Encoder utilities -------------------------------------------------------

  @doc false
  def encoder_for_type(type) do
    case Plushie.Type.resolve(type) do
      {:composite, composite} -> composite_encoder(composite)
      module -> module_encoder(module)
    end
  end

  @doc false
  def composite_encoder(composite) do
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

  @doc false
  def module_encoder(module) do
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

  @doc false
  def cast_encoder(module) do
    quote do
      fn val ->
        case unquote(module).cast(val) do
          {:ok, casted} -> casted
          :error -> raise ArgumentError, "cast failed for value: #{inspect(val)}"
        end
      end
    end
  end

  # -- Constructor generation --------------------------------------------------

  @doc false
  def generate_struct_new(container, positional, props)

  def generate_struct_new(container, [], _props) do
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

  def generate_struct_new(_container, positional, props) do
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

  @doc false
  def generate_with_options(props) do
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

  @doc false
  def generate_prop_validation(props) do
    known_names =
      Enum.map(props, fn {name, _type, _opts} -> name end)

    quote do
      unknown_keys = Keyword.keys(var!(opts)) -- unquote(known_names)

      if unknown_keys != [] do
        raise ArgumentError,
              "unknown option(s) #{inspect(unknown_keys)} for #{inspect(__MODULE__)}.new"
      end
    end
  end

  @doc false
  def positional_guard(type) do
    case type_guard_ast(type, quote(do: __placeholder__)) do
      nil -> nil
      _guard -> fn var -> type_guard_ast(type, var) end
    end
  end

  # -- Setter generation -------------------------------------------------------

  @doc false
  def generate_setters(props, positional) do
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
  @doc false
  def generate_setter_clause(name, doc, value_type, _wants_nil, cast_fn, _guard, _encoder)
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

  def generate_setter_clause(name, doc, value_type, _wants_nil, _cast_fn, nil = _guard, encoder) do
    quote do
      @doc unquote(doc)
      @spec unquote(name)(widget :: t(), value :: unquote(value_type) | nil) :: t()
      def unquote(name)(%__MODULE__{} = widget, value) do
        %{widget | unquote(name) => unquote(encoder).(value)}
      end
    end
  end

  def generate_setter_clause(name, doc, value_type, wants_nil, _cast_fn, guard, encoder) do
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
  @doc false
  def generate_merge_setter_clause(name, type, doc, value_type) do
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

  # -- Guard utilities ---------------------------------------------------------

  # Single source of truth for extracting a guard AST from a type.
  # Returns the guard expression or nil when the type has no guard.
  @doc false
  def type_guard_ast(type, var) do
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

  @doc false
  def setter_guard(type) do
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
  @doc false
  def constraint_guard(_type, []), do: []

  def constraint_guard(type, constraint_opts) do
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
  @doc false
  def combine_guard(base, []), do: base

  def combine_guard(nil, constraints) do
    Enum.reduce(constraints, fn right, left ->
      quote(do: unquote(left) and unquote(right))
    end)
  end

  def combine_guard(base, constraints) do
    Enum.reduce(constraints, base, fn right, left ->
      quote(do: unquote(left) and unquote(right))
    end)
  end

  # -- Field introspection -----------------------------------------------------

  @doc false
  def generate_prop_names(props) do
    known =
      Enum.map(props, fn {name, _type, _opts} -> name end)

    quote do
      @doc false
      def __prop_names__, do: unquote(known)
    end
  end

  @doc false
  def generate_dsl_buildable(props) do
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

  @doc false
  def generate_prop_put_calls(props) do
    Enum.map(props, fn {name, type, opts} ->
      wire_key = Keyword.get(opts, :wire_name, name)

      # Color needs casting in to_node because struct defaults bypass setters.
      # All other types store raw values: Tree.normalize handles encoding.
      if type == Plushie.Type.Color do
        quote do
          var!(props) =
            Plushie.Widget.Build.put_if(
              var!(props),
              var!(widget).unquote(name),
              unquote(wire_key),
              fn val ->
                {:ok, casted} = Plushie.Type.Color.cast(val)
                casted
              end
            )
        end
      else
        quote do
          var!(props) =
            Plushie.Widget.Build.put_if(
              var!(props),
              var!(widget).unquote(name),
              unquote(wire_key)
            )
        end
      end
    end)
  end

  # -- Build helpers -----------------------------------------------------------

  @doc false
  def generate_build(:single) do
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

  def generate_build(_container) do
    quote do
      @doc "Converts this widget struct to a `ui_node()` map."
      @spec build(widget :: t()) :: Plushie.Widget.ui_node()
      def build(%__MODULE__{} = widget), do: Plushie.Widget.to_node(widget)
    end
  end

  @doc false
  def generate_container_helpers do
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
end
