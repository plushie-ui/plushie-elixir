defmodule Plushie.DSL.Element.Codegen do
  @moduledoc false

  # Element-specific code generation for canvas element declarations.
  #
  # Uses `Plushie.DSL.Fields` for shared struct, setter, and type
  # generation. Adds element-specific concerns: `Plushie.Tree.Node`
  # protocol implementation, `type_name/0`, and `encode/1` for
  # backward compatibility with `Plushie.Type.encode_value/1`.

  alias Plushie.DSL.Fields

  # -- Main entry point --------------------------------------------------------

  @doc false
  def generate_element(module, element_type, container, props, positional, opts \\ []) do
    wire_type = Keyword.get(opts, :wire_type)
    type_string = if wire_type, do: Atom.to_string(wire_type), else: Atom.to_string(element_type)

    option_props = Enum.filter(props, fn {_n, _t, opts} -> Keyword.get(opts, :option, true) end)

    struct_def = Fields.generate_struct_and_types(props, container, enforce_id: false)
    {new_fn, auto_id_new_fn} = generate_element_constructors(container, positional, props)
    with_options_fn = Fields.generate_with_options(option_props)
    setters = Fields.generate_setters(props, positional)
    dsl_fns = Fields.generate_dsl_buildable(option_props)
    build_fn = Fields.generate_build(container)
    container_fns = if container, do: Fields.generate_container_helpers(), else: nil
    prop_names_fn = Fields.generate_prop_names(props)

    protocol_impl = generate_element_protocol(module, type_string, container, props)
    encode_fn = generate_encode(type_string, container, props)
    type_name_fn = generate_type_name(type_string)

    quote do
      unquote(struct_def)
      unquote(new_fn)
      unquote(auto_id_new_fn)
      unquote(with_options_fn)
      unquote_splicing(setters)
      unquote(dsl_fns)
      unquote(build_fn)
      unquote(container_fns)
      unquote(prop_names_fn)
      unquote(protocol_impl)
      unquote(encode_fn)
      unquote(type_name_fn)
    end
  end

  # -- Element constructors (id-first + auto-ID) --------------------------------

  # Generates both the id-first and auto-ID constructors for elements.
  # Returns {id_first_ast, auto_id_ast}.
  #
  # For elements without positional args, the id-first and auto-ID
  # forms are both arity 1 (new(id) vs new(opts)). Because Elixir's
  # default-arg header is unguarded, we avoid default args and instead
  # generate explicit clauses at each arity, using is_binary/is_list
  # guards to disambiguate.
  #
  # For elements with positional args, the id-first and auto-ID forms
  # differ in arity (id + N positional vs N positional), so the
  # standard Fields.generate_struct_new works as-is. The auto-ID
  # overload adds a lower-arity clause with type guards on the first
  # positional arg to disambiguate from the binary id.

  @doc false
  def generate_element_constructors(container, [], _props) do
    id_fn =
      if container do
        quote do
          @doc "Creates a new element with the given ID and keyword options."
          @spec new(id :: String.t(), opts :: [option()]) :: t()
          def new(id, opts) when is_binary(id) and is_list(opts) do
            {children, opts} = Keyword.pop(opts, :do, [])
            widget = %__MODULE__{id: id} |> with_options(opts)
            %{widget | children: List.wrap(children)}
          end

          def new(id) when is_binary(id), do: new(id, [])
        end
      else
        quote do
          @doc "Creates a new element with the given ID and keyword options."
          @spec new(id :: String.t(), opts :: [option()]) :: t()
          def new(id, opts) when is_binary(id) and is_list(opts) do
            %__MODULE__{id: id} |> with_options(opts)
          end

          def new(id) when is_binary(id), do: new(id, [])
        end
      end

    auto_id_fn =
      if container do
        quote do
          @doc "Creates a new element without an explicit ID (auto-assigned by parent container)."
          @spec new(opts :: [option()]) :: t()
          def new(opts) when is_list(opts) do
            {children, opts} = Keyword.pop(opts, :do, [])
            element = %__MODULE__{} |> with_options(opts)
            %{element | children: List.wrap(children)}
          end
        end
      else
        quote do
          @doc "Creates a new element without an explicit ID (auto-assigned by parent container)."
          @spec new(opts :: [option()]) :: t()
          def new(opts) when is_list(opts) do
            %__MODULE__{} |> with_options(opts)
          end
        end
      end

    {id_fn, auto_id_fn}
  end

  def generate_element_constructors(_container, positional, props) do
    ctx = __MODULE__
    id_var = Macro.var(:id, ctx)
    opts_var = Macro.var(:opts, ctx)
    positional_vars = Enum.map(positional, fn name -> Macro.var(name, ctx) end)

    positional_guards =
      for name <- positional,
          {^name, type, field_opts} <- props,
          guard_fn = Fields.positional_guard(type) do
        var = Macro.var(name, ctx)
        base = guard_fn.(var)
        has_default = Keyword.has_key?(field_opts, :default)

        if has_default do
          quote(do: unquote(base) or is_nil(unquote(var)))
        else
          base
        end
      end

    pos_guard =
      case positional_guards do
        [] ->
          nil

        [first | rest] ->
          Enum.reduce(rest, first, fn g, acc ->
            quote(do: unquote(acc) and unquote(g))
          end)
      end

    # ID-first: new(id, x, y, w, h, opts) and new(id, x, y, w, h)
    id_struct_pairs =
      [{:id, id_var} | Enum.map(positional, fn name -> {name, Macro.var(name, ctx)} end)]

    id_struct_kw = Enum.map(id_struct_pairs, fn {k, v} -> {k, v} end)

    id_full_guard =
      case pos_guard do
        nil -> quote(do: is_binary(unquote(id_var)))
        g -> quote(do: is_binary(unquote(id_var)) and unquote(g))
      end

    id_fn =
      quote do
        @doc "Creates a new element with the given ID, positional args, and keyword options."
        def new(unquote(id_var), unquote_splicing(positional_vars), unquote(opts_var))
            when unquote(id_full_guard) do
          struct!(__MODULE__, unquote(id_struct_kw))
          |> with_options(unquote(opts_var))
        end

        def new(unquote(id_var), unquote_splicing(positional_vars))
            when unquote(id_full_guard) do
          struct!(__MODULE__, unquote(id_struct_kw))
        end
      end

    # Auto-ID: new(x, y, w, h, opts) and new(x, y, w, h)
    auto_struct_pairs = Enum.map(positional, fn name -> {name, Macro.var(name, ctx)} end)
    auto_struct_kw = Enum.map(auto_struct_pairs, fn {k, v} -> {k, v} end)

    auto_id_fn =
      if pos_guard do
        quote do
          @doc "Creates a new element without an explicit ID (auto-assigned by parent container)."
          def new(unquote_splicing(positional_vars), unquote(opts_var))
              when unquote(pos_guard) do
            struct!(__MODULE__, unquote(auto_struct_kw))
            |> with_options(unquote(opts_var))
          end

          def new(unquote_splicing(positional_vars)) when unquote(pos_guard) do
            struct!(__MODULE__, unquote(auto_struct_kw))
          end
        end
      else
        quote do
        end
      end

    {id_fn, auto_id_fn}
  end

  # -- Tree.Node protocol implementation --------------------------------------

  @doc false
  def generate_element_protocol(_module, type_string, container, props) do
    put_calls = generate_element_prop_put_calls(props)

    children =
      if container do
        quote do
          Plushie.DSL.Element.Codegen.children_to_nodes(
            var!(element).children,
            var!(element).id,
            unquote(type_string)
          )
        end
      else
        quote(do: [])
      end

    quote do
      defimpl Plushie.Tree.Node do
        def to_node(var!(element)) do
          var!(props) = %{}
          unquote_splicing(put_calls)

          # Canvas elements keep their explicit ID in props for the renderer
          # to use as canvas element identifier (event routing, focus tracking).
          var!(props) = Plushie.Widget.Build.put_if(var!(props), var!(element).id, :id)

          %{
            id: var!(element).id,
            type: unquote(type_string),
            props: var!(props),
            children: unquote(children)
          }
        end
      end
    end
  end

  # Generates prop put calls for elements. Unlike widgets, elements
  # encode values immediately via `Plushie.Type.encode_value/1` so
  # the output matches what the existing shape encode pipeline produces.
  defp generate_element_prop_put_calls(props) do
    Enum.map(props, fn {name, _type, opts} ->
      wire_key = Keyword.get(opts, :wire_name, name)

      quote do
        var!(props) =
          case var!(element).unquote(name) do
            nil -> var!(props)
            val -> Map.put(var!(props), unquote(wire_key), Plushie.Type.encode_value(val))
          end
      end
    end)
  end

  # -- encode/1 compatibility -------------------------------------------------

  @doc false
  def generate_encode(type_string, container, props) do
    put_calls = generate_encode_prop_calls(props)

    children_call =
      if container do
        quote do
          var!(result) =
            Map.put(
              var!(result),
              :children,
              Enum.map(element.children, &Plushie.Type.encode_value/1)
            )
        end
      end

    id_call =
      quote do
        var!(result) =
          case element.id do
            nil -> var!(result)
            id -> Map.put(var!(result), :id, id)
          end
      end

    quote do
      @doc false
      def encode(%__MODULE__{} = element) do
        var!(result) = %{type: unquote(type_string)}
        unquote(children_call)
        unquote(id_call)
        unquote_splicing(put_calls)
        var!(result)
      end
    end
  end

  defp generate_encode_prop_calls(props) do
    Enum.map(props, fn {name, _type, opts} ->
      wire_key = Keyword.get(opts, :wire_name, name)

      quote do
        var!(result) =
          case element.unquote(name) do
            nil -> var!(result)
            val -> Map.put(var!(result), unquote(wire_key), Plushie.Type.encode_value(val))
          end
      end
    end)
  end

  # -- type_name/0 -------------------------------------------------------------

  @doc false
  def generate_type_name(type_string) do
    quote do
      @doc "Returns the element type string for the wire protocol."
      @spec type_name() :: String.t()
      def type_name, do: unquote(type_string)
    end
  end

  # -- Runtime helpers for container children ----------------------------------

  @doc false
  @spec children_to_nodes(list(), String.t() | nil, String.t()) :: [map()]
  def children_to_nodes(children, parent_id, type_string) do
    parent_prefix = parent_id || "auto:" <> type_string

    children
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.map(fn {child, idx} ->
      child
      |> Plushie.Tree.Node.to_node()
      |> ensure_child_id(parent_prefix, idx)
    end)
  end

  # Assigns an auto-ID to a child node that has no explicit ID.
  # Leaf shape elements (Rect, Circle, etc.) typically have nil IDs;
  # container shapes (Group, Interactive) have explicit string IDs.
  @doc false
  @spec ensure_child_id(map(), String.t(), non_neg_integer()) :: map()
  def ensure_child_id(node, parent_prefix, idx) do
    if is_nil(node.id) do
      %{node | id: "auto:shape:" <> parent_prefix <> ":" <> Integer.to_string(idx)}
    else
      node
    end
  end
end
