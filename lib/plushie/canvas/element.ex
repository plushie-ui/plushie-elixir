defmodule Plushie.Canvas.Element do
  @moduledoc """
  Behaviour for canvas elements.

  Canvas elements are the building blocks of canvas drawing. Like
  widgets, they produce tree nodes, but they operate in the canvas
  domain: positioned by coordinates rather than layout, drawn by
  the canvas renderer rather than the widget renderer.

  ## Declaring an element

      defmodule MyApp.Canvas.Star do
        use Plushie.Canvas.Element

        element :star do
          field :x, :float
          field :y, :float
          field :radius, :float
          field :points, :integer, default: 5
          field :fill, Plushie.Type.Color
        end
      end

  ## Generated code

  The macro generates:

  - `new/2` constructor (or `new/N` with positional args)
  - Setter functions per field for pipeline composition
  - `with_options/2` for applying keyword options via setters
  - `build/1` for explicit `ui_node()` conversion
  - `type_name/0` returning the element type string
  - `encode/1` for backward compatibility with `Plushie.Type.encode_value`
  - `@type t`, `@type option` typespecs
  - `Plushie.Tree.Node` protocol implementation

  ## Container elements

  Pass `container: true` for group-like elements that hold children:

      element :group, container: true do
        field :opacity, :float
      end

  Container elements get `push/2` and `extend/2` for adding children,
  and `new/2` accepts a `:do` option for inline children.
  """

  alias Plushie.DSL.Element.Codegen
  alias Plushie.DSL.Validation

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :_element_props, accumulate: true)
      Module.put_attribute(__MODULE__, :_element_type_name, nil)
      Module.put_attribute(__MODULE__, :_element_container, false)
      Module.put_attribute(__MODULE__, :_element_positional, nil)

      import Plushie.DSL.Element.Macro,
        only: [element: 1, element: 2, element: 3, positional: 1, field: 2, field: 3]

      @before_compile Plushie.Canvas.Element
    end
  end

  defmacro __before_compile__(env) do
    element_type = Module.get_attribute(env.module, :_element_type_name)
    container = Module.get_attribute(env.module, :_element_container)
    props = Module.get_attribute(env.module, :_element_props) |> Enum.reverse()
    positional = Module.get_attribute(env.module, :_element_positional) || []

    validate_declarations!(env, element_type)
    Validation.validate_prop_types!(env, props)
    Validation.validate_reserved_names!(env, props)
    Validation.warn_duplicate_props(env, props)
    Validation.validate_positional!(env, positional, props)

    Codegen.generate_element(env.module, element_type, container, props, positional)
  end

  defp validate_declarations!(env, element_type) do
    unless element_type do
      raise CompileError,
        file: env.file,
        line: 0,
        description: "missing `element :type_name` declaration in #{inspect(env.module)}"
    end
  end
end
