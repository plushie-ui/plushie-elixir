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
    cast: 1,
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

  # -- Event field parsing -----------------------------------------------------

  @builtin_event_types [:float, :string, :boolean, :any]

  @doc "Returns the list of built-in atomic type identifiers for event fields."
  @spec builtin_event_types() :: [atom()]
  def builtin_event_types, do: @builtin_event_types

  @doc """
  Returns true if the given type identifier is valid for event fields.

  Valid types are built-in atoms (`:float`, `:string`, `:boolean`, `:any`)
  or modules that export `parse/1`.
  """
  @spec valid_event_type?(type :: term()) :: boolean()
  def valid_event_type?(type) when type in @builtin_event_types, do: true

  def valid_event_type?(type) when is_atom(type) do
    Code.ensure_loaded?(type) and function_exported?(type, :parse, 1)
  end

  def valid_event_type?(_), do: false

  @doc """
  Parses a value according to an event field type identifier.

  For built-in atomic types, validates the value matches the expected
  type. For module types, delegates to `module.parse/1`.

  The `:string` type accepts `nil` in addition to binaries, since
  wire-format event fields may be absent (decoded as nil).

  Returns `{:ok, value}` on success, `:error` on failure.
  """
  @spec parse_event_field(type :: atom(), value :: term()) :: {:ok, term()} | :error
  def parse_event_field(:any, value), do: {:ok, value}
  def parse_event_field(:float, value) when is_number(value), do: {:ok, value}
  def parse_event_field(:float, _), do: :error
  def parse_event_field(:string, value) when is_binary(value), do: {:ok, value}
  def parse_event_field(:string, nil), do: {:ok, nil}
  def parse_event_field(:string, _), do: :error
  def parse_event_field(:boolean, value) when is_boolean(value), do: {:ok, value}
  def parse_event_field(:boolean, _), do: :error
  def parse_event_field(module, value) when is_atom(module), do: module.parse(value)

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
