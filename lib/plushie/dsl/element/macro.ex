defmodule Plushie.DSL.Element.Macro do
  @moduledoc false

  # DSL macros for canvas element declarations.
  #
  # These macros are imported into modules that `use Plushie.Canvas.Element`
  # and accumulate module attributes consumed by `__before_compile__`.
  # Simpler than widget macros: no events, state, commands, or Rust
  # integration.

  # -- element/1..2 ------------------------------------------------------------

  @doc """
  Declares the element type name. Pass `container: true` for group-like
  elements that hold children.

  Accepts an optional do-block for grouping field and positional
  declarations:

      element :rect do
        field :x, :float
        field :y, :float
        field :w, :float
        field :h, :float
        field :fill, :any
      end

  ## Container elements

  Pass `container: true` for elements that hold children (groups,
  interactive wrappers):

      element :group, container: true do
        field :opacity, :float
      end
  """
  # When Elixir parses `element :name, key: val do ... end`, the keyword
  # opts and do-block arrive as separate arguments (arity 3). Merge them
  # so the two-arg clause handles everything uniformly.
  defmacro element(type_name, opts, do_block) do
    quote do: element(unquote(type_name), unquote(opts ++ do_block))
  end

  defmacro element(type_name, opts \\ []) do
    validate_element_type_name!(type_name, __CALLER__)
    {block, opts} = Keyword.pop(opts, :do, nil)
    container = Keyword.get(opts, :container, false)

    quote do
      if @_element_type_name do
        IO.warn(
          "element type already declared as #{inspect(@_element_type_name)}, overwriting with #{inspect(unquote(type_name))}"
        )
      end

      @_element_type_name unquote(type_name)
      @_element_container unquote(container)
      unquote(block)
    end
  end

  # -- positional/1 ------------------------------------------------------------

  @doc """
  Declares which fields are positional arguments in `new/N`.

  Fields listed here appear as positional arguments before the `opts`
  keyword in the generated constructor. The order determines the
  argument order.

      positional [:x, :y, :w, :h]

  Generates `new(id, x, y, w, h, opts \\\\ [])` instead of the
  default `new(id, opts \\\\ [])`.
  """
  defmacro positional(names) when is_list(names) do
    quote do
      @_element_positional unquote(names)
    end
  end

  # -- field/2..3 --------------------------------------------------------------

  @doc """
  Declares a typed field on the element.

  Accumulates into `@_element_props`:

      field :x, :float
      field :fill, :any
      field :opacity, :float, default: 1.0

  See `Plushie.DSL.Widget.Macro.field/2` for the full list of
  supported options.
  """
  defmacro field(name, type, opts \\ []) do
    quote do
      @_element_props {unquote(name), unquote(type), unquote(opts)}
    end
  end

  # -- Helpers -----------------------------------------------------------------

  @doc false
  def validate_element_type_name!(type_name, caller) do
    unless is_atom(type_name) do
      raise CompileError,
        file: caller.file,
        line: caller.line,
        description: "element type name must be an atom, got: #{inspect(type_name)}"
    end
  end
end
