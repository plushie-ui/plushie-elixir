defmodule Plushie.Table.Element do
  @moduledoc """
  Behaviour for table structural elements.

  Table elements are the building blocks of table composition.
  Like canvas elements, they produce tree nodes with typed fields,
  but they operate in the table domain: rows and cells within a
  table widget, rendered by the table renderer.

  ## Declaring an element

      defmodule Plushie.Table.Row do
        use Plushie.Table.Element

        element :table_row, container: true do
        end
      end

  ## Generated code

  The macro generates the same code as `Plushie.Canvas.Element`:

  - `new/1` auto-ID constructor
  - `new/2` constructor with explicit ID
  - Setter functions per field
  - `push/2` and `extend/2` for container elements
  - `build/1` for `ui_node()` conversion
  - `Plushie.Tree.Node` protocol implementation

  Uses the same `Plushie.DSL.Element` infrastructure as canvas
  elements. The separate module provides domain-appropriate naming.
  """

  alias Plushie.DSL.Element.Codegen
  alias Plushie.DSL.Validation

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :_element_props, accumulate: true)
      Module.put_attribute(__MODULE__, :_element_type_name, nil)
      Module.put_attribute(__MODULE__, :_element_container, false)
      Module.put_attribute(__MODULE__, :_element_positional, nil)
      Module.put_attribute(__MODULE__, :_element_positional_line, nil)
      Module.put_attribute(__MODULE__, :_element_wire_type, nil)

      import Plushie.DSL.Element.Macro,
        only: [element: 1, element: 2, element: 3, positional: 1, field: 2, field: 3]

      @before_compile Plushie.Table.Element
    end
  end

  defmacro __before_compile__(env) do
    element_type = Module.get_attribute(env.module, :_element_type_name)
    container = Module.get_attribute(env.module, :_element_container)
    wire_type = Module.get_attribute(env.module, :_element_wire_type)
    props = Module.get_attribute(env.module, :_element_props) |> Enum.reverse()
    positional = Module.get_attribute(env.module, :_element_positional) || []
    positional_line = Module.get_attribute(env.module, :_element_positional_line)

    validate_declarations!(env, element_type)
    Validation.validate_prop_types!(env, props)
    Validation.validate_reserved_names!(env, props)
    Validation.warn_duplicate_props(env, props)
    Validation.validate_positional!(env, positional, props, positional_line)

    Codegen.generate_element(env.module, element_type, container, props, positional,
      wire_type: wire_type
    )
  end

  defp validate_declarations!(env, element_type) do
    unless element_type do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "missing `element :type_name` declaration in #{inspect(env.module)}"
    end
  end
end
