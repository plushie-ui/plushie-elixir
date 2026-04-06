defmodule Plushie.Type do
  @moduledoc """
  Behaviour for types in the Plushie DSL.

  Type modules define how values are validated, coerced, guarded in
  function heads, represented in typespecs, and encoded for the wire
  protocol. Used by widget field declarations, event field declarations,
  and composite type definitions.

  ## Atom shortcuts

  Primitive types have atom shortcuts that resolve to built-in modules:

    - `:integer` resolves to `Plushie.Type.Integer`
    - `:float` resolves to `Plushie.Type.Float`
    - `:string` resolves to `Plushie.Type.String`
    - `:boolean` resolves to `Plushie.Type.Boolean`
    - `:atom` resolves to `Plushie.Type.Atom`
    - `:any` resolves to `Plushie.Type.Any`
    - `:map` resolves to `Plushie.Type.Map`

  Domain types use their full module name (e.g. `Plushie.Type.Color`).

  ## Composite constructors

    - `{:enum, [:a, :b, :c]}` for inline enum
    - `{:list, :string}` for typed list
    - `{:tuple, [:float, :float]}` for fixed-size typed tuple
    - `{:union, [Plushie.Type.Color, Plushie.Type.StyleMap]}` for first-successful-cast

  ## Declaring type modules

  Use `use Plushie.Type` with one of three declaration forms:

      # Enum type
      defmodule MyType do
        use Plushie.Type
        enum [:value_a, :value_b, :value_c]
      end

      # Struct type (composite with fields)
      defmodule MyStruct do
        use Plushie.Type
        field :name, :string
        field :count, :integer
      end

      # Union type
      defmodule MyUnion do
        use Plushie.Type
        union do
          enum [:preset_a, :preset_b]
          type Plushie.Type.StyleMap
        end
      end

  Modules without declarations implement callbacks manually.
  """

  @callback cast(term()) :: {:ok, term()} | :error
  @callback typespec() :: Macro.t()
  @callback guard(Macro.t()) :: Macro.t() | nil
  @callback encode(term()) :: term()
  @callback fields() :: [{atom(), term()}] | nil
  @callback field_options() :: [atom()]
  @callback constrain_guard(Macro.t(), keyword()) :: [Macro.t()]

  @optional_callbacks [
    guard: 1,
    encode: 1,
    fields: 0,
    field_options: 0,
    constrain_guard: 2
  ]

  # -- resolve/1 ---------------------------------------------------------------

  @primitive_shortcuts %{
    integer: Plushie.Type.Integer,
    float: Plushie.Type.Float,
    string: Plushie.Type.String,
    boolean: Plushie.Type.Boolean,
    atom: Plushie.Type.Atom,
    any: Plushie.Type.Any,
    map: Plushie.Type.Map
  }

  @doc """
  Resolves a type reference to a module or composite descriptor.

  Accepts primitive atom shortcuts (`:integer`, `:string`, etc.),
  module names, and composite tuple forms (`{:enum, [...]}`).
  """
  @spec resolve(term()) :: module() | {:composite, term()}
  def resolve(shortcut) when is_map_key(@primitive_shortcuts, shortcut) do
    Map.fetch!(@primitive_shortcuts, shortcut)
  end

  def resolve(module) when is_atom(module), do: module

  def resolve({kind, _} = ref) when kind in [:enum, :list, :tuple, :union] do
    {:composite, ref}
  end

  @doc "Returns the map of primitive atom shortcuts to their type modules."
  @spec primitive_shortcuts() :: %{atom() => module()}
  def primitive_shortcuts, do: @primitive_shortcuts

  @doc "Returns true if the given atom is a known primitive type shortcut."
  @spec shortcut?(atom()) :: boolean()
  def shortcut?(name) when is_atom(name) do
    is_map_key(@primitive_shortcuts, name)
  end

  # -- Event field casting -----------------------------------------------------

  @doc """
  Returns true if the given type identifier is valid for event fields.

  Valid types are primitive shortcuts, modules implementing Plushie.Type
  (with `cast/1`), or modules with `parse/1`.
  """
  @spec valid_event_type?(type :: term()) :: boolean()
  def valid_event_type?(type) when is_atom(type) do
    shortcut?(type) or type_has_cast?(type)
  end

  def valid_event_type?(_), do: false

  defp type_has_cast?(module) do
    Code.ensure_loaded?(module) and
      (function_exported?(module, :cast, 1) or function_exported?(module, :parse, 1))
  end

  @doc """
  Casts a value according to a type identifier.

  Resolves the type via `resolve/1` and delegates to the type module's
  `cast/1`. The `:string` type accepts `nil` (wire-format absent fields).

  Returns `{:ok, value}` on success, `:error` on failure.
  """
  @spec cast_field(type :: term(), value :: term()) :: {:ok, term()} | :error
  def cast_field(:string, nil), do: {:ok, nil}

  def cast_field(type, value) do
    cast_value(type, value)
  end

  # -- Composite type casts ----------------------------------------------------

  @doc """
  Casts a value according to a composite type constructor.

  Composite types are `{:list, inner}`, `{:tuple, [types]}`,
  `{:enum, [atoms]}`, and `{:union, [types]}`.
  """
  @spec cast_composite(
          {:list, term()} | {:tuple, [term()]} | {:enum, [atom()]} | {:union, [term()]},
          term()
        ) :: {:ok, term()} | :error
  def cast_composite({:list, inner_type}, value) when is_list(value) do
    results = Enum.map(value, fn el -> cast_value(inner_type, el) end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, v} -> v end)}
    else
      :error
    end
  end

  def cast_composite({:list, _}, _), do: :error

  def cast_composite({:tuple, types}, value)
      when is_tuple(value) and tuple_size(value) == length(types) do
    pairs = Enum.zip(types, Tuple.to_list(value))
    results = Enum.map(pairs, fn {type, val} -> cast_value(type, val) end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, List.to_tuple(Enum.map(results, fn {:ok, v} -> v end))}
    else
      :error
    end
  end

  def cast_composite({:tuple, _}, _), do: :error

  def cast_composite({:enum, values}, value) do
    if value in values, do: {:ok, value}, else: :error
  end

  def cast_composite({:union, types}, value) do
    Enum.find_value(types, :error, fn type ->
      case cast_value(type, value) do
        {:ok, v} -> {:ok, v}
        :error -> nil
      end
    end)
  end

  @doc """
  Universal cast entry point that handles both module types and composite types.

  Resolves the type via `resolve/1` and delegates to either
  `cast_composite/2` or the type module's `cast/1`.
  """
  @spec cast_value(term(), term()) :: {:ok, term()} | :error
  def cast_value(type, value) do
    case resolve(type) do
      {:composite, composite} -> cast_composite(composite, value)
      module -> module.cast(value)
    end
  end

  # -- Value encoding ----------------------------------------------------------

  @doc """
  Encodes a value to its wire-safe representation.

  Handles primitives (atoms become strings, tuples become lists) and
  structs (delegates to `module.encode/1` when available). This replaces
  the former `Plushie.Encode` protocol dispatch.
  """
  @spec encode_value(term()) :: term()
  def encode_value(%module{} = v) do
    if Code.ensure_loaded?(module) and function_exported?(module, :encode, 1) do
      module.encode(v)
    else
      v
    end
  end

  def encode_value(%{} = map) do
    Map.new(map, fn {k, v} -> {k, encode_value(v)} end)
  end

  def encode_value(list) when is_list(list), do: Enum.map(list, &encode_value/1)

  def encode_value(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&encode_value/1)
  end

  def encode_value(true), do: true
  def encode_value(false), do: false
  def encode_value(nil), do: nil
  def encode_value(v) when is_atom(v), do: Atom.to_string(v)
  def encode_value(v), do: v

  # -- use Plushie.Type --------------------------------------------------------

  defmacro __using__(_opts) do
    quote do
      @behaviour Plushie.Type

      Module.register_attribute(__MODULE__, :_type_enum, accumulate: false)
      Module.register_attribute(__MODULE__, :_type_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :_type_union_variants, accumulate: true)
      Module.register_attribute(__MODULE__, :_type_union, accumulate: false)

      import Plushie.Type, only: [enum: 1, field: 2, field: 3, union: 1, type: 1]

      @before_compile Plushie.Type
    end
  end

  # -- DSL macros --------------------------------------------------------------

  @doc false
  defmacro enum(values) when is_list(values) do
    quote do
      @_type_enum unquote(values)
    end
  end

  @doc false
  defmacro field(name, type, opts \\ []) do
    quote do
      @_type_fields {unquote(name), unquote(type), unquote(opts)}
    end
  end

  @doc false
  defmacro union(do: block) do
    quote do
      @_type_union true
      unquote(block)
    end
  end

  # Inside union blocks, `enum` and `type` accumulate into @_type_union_variants.
  # We need separate macros for the union context. Since `enum` is already defined,
  # we detect union context in __before_compile__ by checking @_type_union.
  # The `type` macro is only valid inside union blocks.

  @doc false
  defmacro type(module) do
    quote do
      @_type_union_variants {:type, unquote(module)}
    end
  end

  # -- @before_compile ---------------------------------------------------------

  defmacro __before_compile__(env) do
    type_enum = Module.get_attribute(env.module, :_type_enum)
    type_fields = Module.get_attribute(env.module, :_type_fields) |> Enum.reverse()
    type_union = Module.get_attribute(env.module, :_type_union)
    union_variants = Module.get_attribute(env.module, :_type_union_variants) |> Enum.reverse()

    cond do
      type_union ->
        generate_union(union_variants, type_enum)

      type_enum != nil ->
        generate_enum(type_enum)

      type_fields != [] ->
        generate_struct(type_fields, env.module)

      true ->
        # Manual implementation, nothing to generate
        quote do: :ok
    end
  end

  # -- Enum code generation ----------------------------------------------------

  defp generate_enum(values) do
    atom_strings = Enum.map(values, &Atom.to_string/1)
    values_for_match = Enum.map(values, &Macro.escape/1)

    quote do
      @impl Plushie.Type
      def cast(v) when v in unquote(values_for_match), do: {:ok, v}

      def cast(v) when is_binary(v) do
        if v in unquote(atom_strings) do
          {:ok, String.to_existing_atom(v)}
        else
          :error
        end
      end

      def cast(_), do: :error

      @impl Plushie.Type
      def typespec do
        values = unquote(values_for_match)

        Enum.reduce(Enum.reverse(values), fn val, acc ->
          {:|, [], [val, acc]}
        end)
      end

      @_type_enum_values unquote(values_for_match)

      @impl Plushie.Type
      def guard(var) do
        quote do: unquote(var) in unquote(@_type_enum_values)
      end

      @impl Plushie.Type
      def encode(v) when v in unquote(values_for_match), do: Atom.to_string(v)
    end
  end

  # -- Struct code generation --------------------------------------------------

  defp generate_struct(fields, _module) do
    field_defaults = Enum.map(fields, fn {name, _type, opts} -> {name, opts[:default]} end)
    field_types_map = Enum.map(fields, fn {name, type, _opts} -> {name, type} end)

    quote do
      defstruct unquote(field_defaults)

      @impl Plushie.Type
      def cast(v) when is_map(v) do
        field_types = unquote(Macro.escape(field_types_map))

        Enum.reduce_while(field_types, {:ok, %{}}, fn {name, type_ref}, {:ok, acc} ->
          value = Map.get(v, name) || Map.get(v, Atom.to_string(name))
          resolved = Plushie.Type.resolve(type_ref)

          case cast_field(resolved, value) do
            {:ok, parsed} -> {:cont, {:ok, Map.put(acc, name, parsed)}}
            :error -> {:halt, :error}
          end
        end)
        |> case do
          {:ok, map} -> {:ok, struct(__MODULE__, map)}
          :error -> :error
        end
      end

      def cast(_), do: :error

      defp cast_field(module, nil) when is_atom(module), do: {:ok, nil}

      defp cast_field(module, value) when is_atom(module) do
        module.cast(value)
      end

      defp cast_field({:composite, _}, value), do: {:ok, value}

      @impl Plushie.Type
      def typespec do
        quote do: %unquote(__MODULE__){}
      end

      @impl Plushie.Type
      def guard(var) do
        mod = __MODULE__
        quote do: is_struct(unquote(var), unquote(mod))
      end

      @impl Plushie.Type
      def fields, do: unquote(Macro.escape(field_types_map))
    end
  end

  # -- Union code generation ---------------------------------------------------

  defp generate_union(variants, enum_values) do
    # Inside a union block, `enum` sets @_type_enum and `type` pushes to @_type_union_variants.
    # We combine both into the variant list.
    all_variants =
      if enum_values do
        [{:enum, enum_values} | variants]
      else
        variants
      end

    quote do
      @_union_variants unquote(Macro.escape(all_variants))

      @impl Plushie.Type
      def cast(value) do
        Enum.find_value(@_union_variants, :error, fn variant ->
          case try_variant(variant, value) do
            {:ok, _} = ok -> ok
            :error -> nil
          end
        end)
      end

      defp try_variant({:enum, atoms}, value) when is_atom(value) do
        if value in atoms, do: {:ok, value}, else: :error
      end

      defp try_variant({:enum, atoms}, value) when is_binary(value) do
        atom_strings = Enum.map(atoms, &Atom.to_string/1)

        if value in atom_strings do
          {:ok, String.to_existing_atom(value)}
        else
          :error
        end
      end

      defp try_variant({:enum, _}, _), do: :error

      defp try_variant({:type, module}, value) do
        resolved = Plushie.Type.resolve(module)

        case resolved do
          {:composite, _} -> {:ok, value}
          mod -> mod.cast(value)
        end
      end

      @impl Plushie.Type
      def typespec do
        quote do: term()
      end
    end
  end
end
