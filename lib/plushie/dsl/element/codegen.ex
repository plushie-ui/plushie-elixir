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
    new_fn = Fields.generate_struct_new(container, positional, props)
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

  # -- Tree.Node protocol implementation --------------------------------------

  @doc false
  def generate_element_protocol(_module, type_string, container, props) do
    put_calls = generate_element_prop_put_calls(props)

    children =
      if container do
        quote do
          Enum.reverse(var!(element).children)
          |> Enum.map(&Plushie.Tree.Node.to_node/1)
        end
      else
        quote(do: [])
      end

    quote do
      defimpl Plushie.Tree.Node do
        def to_node(var!(element)) do
          var!(props) = %{}
          unquote_splicing(put_calls)

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
end
