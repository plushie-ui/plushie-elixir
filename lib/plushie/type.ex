defmodule Plushie.Type do
  @moduledoc """
  Types for widget fields and events.

  Widget field declarations like `field :name, :string` or
  `field :color, Plushie.Type.Color` each name a type. The type
  determines what values a field accepts, how they appear in
  typespecs, and how they encode for the renderer.

  The SDK includes types for common values; when your application
  needs something more specific, you can define your own by
  implementing the `Plushie.Type` behaviour.

  ## Primitive types

  Types for basic values like numbers, strings, and booleans,
  represented as atoms in field declarations:

    - `:integer` - `Plushie.Type.Integer`
    - `:float` - `Plushie.Type.Float`
    - `:string` - `Plushie.Type.String`
    - `:boolean` - `Plushie.Type.Boolean`
    - `:atom` - `Plushie.Type.Atom`
    - `:any` - `Plushie.Type.Any`
    - `:map` - `Plushie.Type.Map`

  Example in a field declaration:

      field :label, :string
      field :count, :integer, default: 0

  ## Domain types

  The SDK includes additional types beyond the primitives, referenced
  by module name. Some examples:

    - `Plushie.Type.Color` - CSS colors (named atoms, hex strings, RGBA maps)
    - `Plushie.Type.Padding` - uniform number, `{v, h}` tuple, or per-side map
    - `Plushie.Type.Font` - font family, weight, style, and stretch
    - `Plushie.Type.Border` - color, width, and radius
    - `Plushie.Type.A11y` - accessibility annotations

  Example in a field declaration:

      field :color, Plushie.Type.Color
      field :padding, Plushie.Type.Padding, default: 8

  ## Composite types

  When you need a list of values, a set of specific atoms, or a
  choice between types, you can express that directly in the field
  declaration:

    - `{:enum, [:a, :b, :c]}` - one of a fixed set of atoms
    - `{:list, :string}` - list where every element matches the inner type
    - `{:map, {:string, :integer}}` - map with typed keys and values
    - `{:map, [name: :string, age: :integer]}` - map with specific named fields
    - `{:tuple, [:float, :float]}` - fixed-size tuple with typed positions
    - `{:union, [Plushie.Type.Color, Plushie.Type.StyleMap]}` - tries each type in order, first successful cast wins

  Example in a field declaration:

      field :tags, {:list, :string}
      field :mode, {:enum, [:read, :write]}
      field :scores, {:map, {:string, :integer}}

  ## Building your own type

  If the built-in types and composite types don't quite fit,
  you can define your own. All custom types start with
  `use Plushie.Type`. From there, you can either compose existing
  types using the DSL macros, or implement callbacks directly for
  more control.

  ### Composing with the DSL

  The DSL macros let you build types from existing ones. All
  callbacks are generated automatically.

  **Enum** for a fixed set of atom values:

      defmodule MyApp.Type.Priority do
        use Plushie.Type
        enum [:low, :medium, :high, :critical]
      end

  **Struct** for grouping related fields into a single value:

      defmodule MyApp.Type.Dimensions do
        use Plushie.Type

        struct do
          field :width, :float
          field :height, :float
        end
      end

  **Union** when a field accepts multiple forms (first match wins):

      defmodule MyApp.Type.Size do
        use Plushie.Type

        union do
          enum [:small, :medium, :large]
          type MyApp.Type.Dimensions
        end
      end

  Use them in widget field declarations by module name:

      field :priority, MyApp.Type.Priority, default: :medium
      field :size, MyApp.Type.Size

  ### Custom callbacks

  When you need custom validation, coercion from multiple input
  forms, or encoding logic that the DSL can't express, you can
  implement the callbacks directly. You still start with
  `use Plushie.Type`.

  A type needs at least `cast/1` and `typespec/0`. Adding `guard/1`
  enables pattern matching in generated setters, and `encode/1`
  handles cases where the wire representation differs from the
  Elixir value:

      defmodule MyApp.Type.Percentage do
        use Plushie.Type

        # Accept integers 0..100 or floats 0.0..1.0, normalize to float
        @impl true
        def cast(v) when is_integer(v) and v >= 0 and v <= 100, do: {:ok, v / 100}
        def cast(v) when is_float(v) and v >= 0.0 and v <= 1.0, do: {:ok, v}
        def cast(_), do: :error

        @impl true
        def typespec, do: quote(do: float())

        @impl true
        def guard(var), do: quote(do: is_float(unquote(var)))

        # encode/1 not needed: floats are already wire-safe
      end

  You can also delegate to other types within your callbacks.
  This is useful when your type wraps or combines existing types
  with custom logic:

      def cast(%{fg: fg, bg: bg}) do
        with {:ok, fg} <- Plushie.Type.Color.cast(fg),
             {:ok, bg} <- Plushie.Type.Color.cast(bg) do
          {:ok, %{fg: fg, bg: bg}}
        else
          _ -> :error
        end
      end

  `Plushie.Type.Integer` serves as a minimal reference.
  `Plushie.Type.Color` shows how to handle many input forms.

  ## Callbacks

  Required:

    - `cast/1` - validates input, returns `{:ok, normalized}` or
      `:error`. Defines what values are accepted and what canonical
      form they take.
    - `typespec/0` - returns a quoted typespec
      (e.g. `quote(do: float())`). Used in generated `@type` and
      `@spec` attributes.

  Optional:

    - `castable/0` - returns a quoted typespec for the values
      `cast/1` accepts. Default: same as `typespec/0`. Implement
      when the input forms are broader than the canonical type
      (e.g., Color accepts atoms, strings, and maps but stores a
      hex string).
    - `decode/1` - decodes a wire-format value (JSON-decoded
      strings, numbers, maps with string keys) into the canonical
      type. Default: delegates to `cast/1`. Implement when wire
      and Elixir representations differ (e.g., enums receive
      strings but store atoms).
    - `encode/1` - converts to wire-safe form (atoms to strings,
      structs to maps). Only needed when the Elixir value isn't
      directly serializable.
    - `guard/1` - returns a quoted guard expression. Enables pattern
      matching in generated setter functions.
    - `fields/0` - for struct types, returns `[{name, type}, ...]`.
    - `field_options/0` - declares constraint keys (e.g.
      `[:min, :max]`). Validated at compile time.
    - `constrain_guard/2` - generates guards from field constraints
      (e.g. range checks from `:min`/`:max` options).
    - `merge/2` - controls how a field default combines with a user
      override. Default: full replacement. Implement for struct types
      where partial updates should preserve unset fields.
    - `resolve/2` - derives the final value from sibling widget props
      at render time. Default: identity. Implement when your type
      needs to read other props to compute its value.
  """

  @callback cast(term()) :: {:ok, term()} | :error
  @callback typespec() :: Macro.t()
  @callback guard(Macro.t()) :: Macro.t() | nil
  @callback encode(term()) :: term()
  @callback fields() :: [{atom(), term()}] | nil
  @callback field_options() :: [atom()]
  @callback constrain_guard(Macro.t(), keyword()) :: [Macro.t()]

  @doc """
  Merges a default value with a user-provided override.

  When a widget field has a default value and the user also provides a
  value, this callback controls how the two combine. The default
  implementation replaces the default entirely with the override, which
  is correct for most types.

  Struct types with many optional fields can implement field-level
  merge instead. Consider a `%Config{theme: nil, locale: nil}` type.
  A widget declares `default: %Config{theme: :dark}` and the user
  sets `config: %Config{locale: :en}`. A field-level merge produces
  `%Config{theme: :dark, locale: :en}` rather than discarding the
  default theme.

  Implement this callback when your type is a struct and partial
  overrides should preserve unset defaults. See `Plushie.Type.A11y`
  for a real-world example.
  """
  @callback merge(default :: term(), override :: term()) :: term()

  @doc """
  Resolves derived values after all widget props are set.

  Called during tree normalization with the current field value and the
  full props map of the widget. This lets a type compute its final
  value based on sibling props that aren't known at declaration time.

  For example, imagine a type with a `derive_from` field that names
  another prop. A widget declares `field :tooltip, MyType, default:
  %MyType{derive_from: :label}`. When `resolve/2` runs, it looks up
  the `:label` prop from the props map and uses it as the tooltip
  value. The `derive_from` directive is cleared since it only exists
  to guide resolution, not to appear on the wire.

  Most types don't need this. Implement it only when your type must
  read other widget props to compute its final value. See
  `Plushie.Type.A11y` for a real-world example.
  """
  @callback resolve(value :: term(), props :: map()) :: term()

  @doc """
  Returns the quoted typespec for values accepted by `cast/1`.

  For types that normalize input (e.g., Color accepts atoms, strings,
  and maps but stores a hex string), this describes the broader input
  surface. Widget setter `@spec` annotations use this so dialyzer
  and documentation reflect what users can actually pass.

  Defaults to `typespec/0` when not implemented, which is correct
  for types where the input and canonical forms are the same.
  """
  @callback castable() :: Macro.t()

  @doc """
  Decodes a wire-format value into the canonical type.

  Wire data arrives as JSON-decoded values (strings, numbers,
  booleans, lists, maps with string keys). This callback handles
  coercion from those wire representations to the canonical Elixir
  type.

  Defaults to `cast/1` when not implemented, which is correct for
  types where wire and Elixir representations are the same
  (integers, floats, strings, booleans).

  Types where wire and Elixir differ should implement this. For
  example, enums receive strings from the wire but store atoms.
  """
  @callback decode(term()) :: {:ok, term()} | :error

  @optional_callbacks [
    castable: 0,
    constrain_guard: 2,
    decode: 1,
    encode: 1,
    field_options: 0,
    fields: 0,
    guard: 1,
    merge: 2,
    resolve: 2
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

  @composite_modules %{
    enum: Plushie.Type.Composite.Enum,
    list: Plushie.Type.Composite.List,
    map: Plushie.Type.Composite.Map,
    tuple: Plushie.Type.Composite.Tuple,
    union: Plushie.Type.Composite.Union
  }

  @doc """
  Resolves a type reference to a module or composite descriptor.

  Accepts primitive atom shortcuts (`:integer`, `:string`, etc.),
  module names, and composite tuple forms (`{:enum, [...]}`,
  `{:list, type}`, `{:map, spec}`, `{:tuple, [types]}`,
  `{:union, [types]}`).
  """
  @spec resolve(term()) :: module() | {:composite, term()}
  def resolve(shortcut) when is_map_key(@primitive_shortcuts, shortcut) do
    Map.fetch!(@primitive_shortcuts, shortcut)
  end

  def resolve(module) when is_atom(module), do: module

  def resolve({kind, _} = ref) when is_map_key(@composite_modules, kind) do
    {:composite, ref}
  end

  @doc "Returns the composite module for the given kind atom."
  @spec composite_module(atom()) :: module()
  def composite_module(kind) when is_map_key(@composite_modules, kind) do
    Map.fetch!(@composite_modules, kind)
  end

  @doc "Returns true if the given atom is a known composite kind."
  @spec composite_kind?(atom()) :: boolean()
  def composite_kind?(kind) when is_atom(kind), do: is_map_key(@composite_modules, kind)

  @doc "Returns the map of primitive atom shortcuts to their type modules."
  @spec primitive_shortcuts() :: %{atom() => module()}
  def primitive_shortcuts, do: @primitive_shortcuts

  @doc "Returns true if the given atom is a known primitive type shortcut."
  @spec shortcut?(atom()) :: boolean()
  def shortcut?(name) when is_atom(name) do
    is_map_key(@primitive_shortcuts, name)
  end

  @doc """
  Merges a default value with a user override using the type's merge semantics.

  Falls back to simple replacement if the type module doesn't implement merge/2.
  """
  @spec merge_value(module(), term(), term()) :: term()
  def merge_value(type_mod, default, override) when is_atom(type_mod) do
    if function_exported?(type_mod, :merge, 2) do
      type_mod.merge(default, override)
    else
      override
    end
  end

  @doc """
  Resolves derived values using the type's resolve semantics.

  Falls back to identity if the type module doesn't implement resolve/2.
  """
  @spec resolve_value(module(), term(), map()) :: term()
  def resolve_value(type_mod, value, props) when is_atom(type_mod) do
    if function_exported?(type_mod, :resolve, 2) do
      type_mod.resolve(value, props)
    else
      value
    end
  end

  # -- Union helpers (used by DSL-generated unions) ----------------------------

  @doc false
  @spec cast_union_variants([{:enum, [atom()]} | {:type, term()}], term()) ::
          {:ok, term()} | :error
  def cast_union_variants(variants, value) do
    Enum.find_value(variants, :error, fn
      {:enum, atoms} -> if value in atoms, do: {:ok, value}
      {:type, type_ref} -> ok_or_nil(cast_value(type_ref, value))
    end)
  end

  @doc false
  @spec decode_union_variants([{:enum, [atom()]} | {:type, term()}], term()) ::
          {:ok, term()} | :error
  def decode_union_variants(variants, value) do
    Enum.find_value(variants, :error, fn
      {:enum, atoms} -> decode_enum_variant(atoms, value)
      {:type, type_ref} -> ok_or_nil(decode_value(type_ref, value))
    end)
  end

  defp decode_enum_variant(atoms, value) when is_atom(value) do
    if value in atoms, do: {:ok, value}
  end

  defp decode_enum_variant(atoms, value) when is_binary(value) do
    Enum.find_value(atoms, fn
      atom when is_atom(atom) ->
        if Atom.to_string(atom) == value, do: {:ok, atom}

      _ ->
        nil
    end)
  end

  defp decode_enum_variant(_, _), do: nil

  defp ok_or_nil({:ok, _} = ok), do: ok
  defp ok_or_nil(:error), do: nil

  @doc false
  @spec union_typespec([{:enum, [atom()]} | {:type, module()}]) :: Macro.t()
  def union_typespec(variants) do
    variant_types =
      Enum.flat_map(variants, fn
        {:enum, atoms} -> atoms
        {:type, module} -> [typespec_for_module(module)]
      end)

    case variant_types do
      [] -> quote(do: term())
      types -> Enum.reduce(Enum.reverse(types), fn t, acc -> {:|, [], [t, acc]} end)
    end
  end

  defp typespec_for_module(module) do
    case resolve(module) do
      {:composite, _} ->
        quote(do: term())

      mod ->
        if Code.ensure_loaded?(mod) and function_exported?(mod, :typespec, 0) do
          mod.typespec()
        else
          quote(do: term())
        end
    end
  end

  # -- Event field casting -----------------------------------------------------

  @doc """
  Returns true if the given type identifier is valid for event fields.

  Valid types are primitive shortcuts, modules implementing Plushie.Type
  (with `cast/1`), modules with `parse/1`, or composite type tuples.
  """
  @spec valid_event_type?(type :: term()) :: boolean()
  def valid_event_type?(type) when is_atom(type) do
    shortcut?(type) or type_has_cast?(type)
  end

  def valid_event_type?({kind, spec}) when is_map_key(@composite_modules, kind) do
    composite_module(kind).valid_spec?(spec, &valid_event_type?/1)
  end

  def valid_event_type?(_), do: false

  defp type_has_cast?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :cast, 1)
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

  Dispatches to the appropriate `Plushie.Type.Composite` module
  based on the composite kind.
  """
  @spec cast_composite({atom(), term()}, term()) :: {:ok, term()} | :error
  def cast_composite({kind, spec}, value) when is_map_key(@composite_modules, kind) do
    composite_module(kind).cast(spec, value)
  end

  @doc """
  Casts a named field value, treating nil as a valid absent value.

  Used by map record composites and struct type cast.
  """
  @spec cast_optional_field(term(), term()) :: {:ok, term()} | :error
  def cast_optional_field(_type, nil), do: {:ok, nil}
  def cast_optional_field(type, value), do: cast_value(type, value)

  @doc """
  Decodes a named field value from wire format, treating nil as absent.
  """
  @spec decode_optional_field(term(), term()) :: {:ok, term()} | :error
  def decode_optional_field(_type, nil), do: {:ok, nil}
  def decode_optional_field(type, value), do: decode_value(type, value)

  @doc """
  Casts a map or keyword list against a list of `{name, type}` field specs.

  Looks up each field by atom key first, then by string key as a
  fallback. Casts through the field's type and returns `{:ok, map}`
  or `:error`. Missing fields become nil.
  """
  @spec cast_named_fields([{atom(), term()}], map() | keyword()) :: {:ok, map()} | :error
  def cast_named_fields(field_specs, input) when is_map(input) do
    do_named_fields(field_specs, input, &cast_optional_field/2)
  end

  def cast_named_fields(field_specs, input) when is_list(input) do
    if Keyword.keyword?(input) do
      do_named_fields(field_specs, Map.new(input), &cast_optional_field/2)
    else
      :error
    end
  end

  @doc """
  Decodes a map against a list of `{name, type}` field specs using
  the decode path. Like `cast_named_fields/2` but uses `decode_value`
  for inner types (handling wire representations).
  """
  @spec decode_named_fields([{atom(), term()}], map()) :: {:ok, map()} | :error
  def decode_named_fields(field_specs, input) when is_map(input) do
    do_named_fields(field_specs, input, &decode_optional_field/2)
  end

  defp do_named_fields(field_specs, map, field_fn) do
    Enum.reduce_while(field_specs, {:ok, %{}}, fn {name, type_ref}, {:ok, acc} ->
      raw =
        case Map.fetch(map, name) do
          {:ok, val} -> val
          :error -> Map.get(map, Atom.to_string(name))
        end

      case field_fn.(type_ref, raw) do
        {:ok, parsed} -> {:cont, {:ok, Map.put(acc, name, parsed)}}
        :error -> {:halt, :error}
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

  # -- Wire decoding -----------------------------------------------------------

  @doc """
  Decodes a wire-format event field value.

  Like `cast_field/2` but uses the type's `decode/1` callback,
  which handles wire representations (strings for enums, lists for
  tuples, etc.).
  """
  @spec decode_field(type :: term(), value :: term()) :: {:ok, term()} | :error
  def decode_field(:string, nil), do: {:ok, nil}

  def decode_field(type, value) do
    decode_value(type, value)
  end

  @doc """
  Decodes a wire-format value through the type's decode path.

  Like `cast_value/2` but uses `decode/1` for module types and
  `decode/2` for composite types.
  """
  @spec decode_value(term(), term()) :: {:ok, term()} | :error
  def decode_value(type, value) do
    case resolve(type) do
      {:composite, {kind, spec}} -> composite_module(kind).decode(spec, value)
      module -> module.decode(value)
    end
  end

  # -- Value encoding ----------------------------------------------------------

  @doc """
  Encodes a value to its wire-safe representation.

  Handles primitives (atoms become strings, tuples become lists) and
  structs (delegates to `module.encode/1` when available, otherwise
  strips `__struct__` and recursively encodes the map).
  """
  @spec encode_value(term()) :: term()
  def encode_value(%module{} = v) do
    if Code.ensure_loaded?(module) and function_exported?(module, :encode, 1) do
      module.encode(v)
    else
      v |> Map.from_struct() |> encode_value()
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
      Module.register_attribute(__MODULE__, :_type_struct, accumulate: false)
      Module.register_attribute(__MODULE__, :_type_union, accumulate: false)
      Module.register_attribute(__MODULE__, :_type_union_variants, accumulate: true)

      import Kernel, except: [struct: 1]

      import Plushie.Type,
        only: [enum: 1, field: 2, field: 3, struct: 1, type: 1, union: 1]

      @before_compile Plushie.Type
    end
  end

  # -- DSL macros --------------------------------------------------------------

  @doc false
  defmacro enum(values) when is_list(values) do
    quote do
      if @_type_union do
        @_type_union_variants {:enum, unquote(values)}
      else
        if @_type_struct do
          raise CompileError,
            description: "cannot combine enum with struct"
        end

        @_type_enum unquote(values)
      end
    end
  end

  @doc false
  defmacro field(name, type, opts \\ []) do
    quote do
      unless @_type_struct do
        raise CompileError,
          description: "field declarations must be inside a struct do ... end block"
      end

      @_type_fields {unquote(name), unquote(type), unquote(opts)}
    end
  end

  @doc false
  defmacro struct(do: block) do
    quote do
      if @_type_enum || @_type_union do
        raise CompileError,
          description: "cannot combine struct with other type declarations"
      end

      @_type_struct true
      unquote(block)
    end
  end

  @doc false
  defmacro union(do: block) do
    quote do
      if @_type_enum || @_type_struct do
        raise CompileError,
          description: "cannot combine union with other type declarations"
      end

      @_type_union true
      unquote(block)
    end
  end

  # Inside union blocks, `enum` pushes {:enum, values} to @_type_union_variants
  # instead of setting @_type_enum. `type` also pushes to @_type_union_variants.

  @doc false
  defmacro type(module) do
    quote do
      unless @_type_union do
        raise CompileError,
          description: "type can only be used inside a union block"
      end

      @_type_union_variants {:type, unquote(module)}
    end
  end

  # -- @before_compile ---------------------------------------------------------

  defmacro __before_compile__(env) do
    type_enum = Module.get_attribute(env.module, :_type_enum)
    type_struct = Module.get_attribute(env.module, :_type_struct)
    type_fields = Module.get_attribute(env.module, :_type_fields) |> Enum.reverse()
    type_union = Module.get_attribute(env.module, :_type_union)
    union_variants = Module.get_attribute(env.module, :_type_union_variants) |> Enum.reverse()

    type_code =
      cond do
        type_union ->
          generate_union(union_variants)

        type_enum != nil ->
          generate_enum(type_enum)

        type_struct ->
          generate_struct(type_fields)

        true ->
          # Manual implementation, nothing to generate
          quote do: :ok
      end

    # Default implementations for optional callbacks.
    defaults =
      quote do
        unless Module.defines?(__MODULE__, {:castable, 0}) do
          @impl Plushie.Type
          def castable, do: typespec()
        end

        unless Module.defines?(__MODULE__, {:decode, 1}) do
          @impl Plushie.Type
          def decode(value), do: cast(value)
        end

        unless Module.defines?(__MODULE__, {:merge, 2}) do
          @impl Plushie.Type
          def merge(_default, override), do: override
        end

        unless Module.defines?(__MODULE__, {:resolve, 2}) do
          @impl Plushie.Type
          def resolve(value, _props), do: value
        end
      end

    quote do
      unquote(type_code)
      unquote(defaults)
    end
  end

  # -- Enum code generation ----------------------------------------------------

  defp generate_enum(values) do
    atom_strings = Enum.map(values, &Atom.to_string/1)
    values_for_match = Enum.map(values, &Macro.escape/1)

    quote do
      @impl Plushie.Type
      def cast(v) when v in unquote(values_for_match), do: {:ok, v}
      def cast(_), do: :error

      @impl Plushie.Type
      def decode(v) when v in unquote(values_for_match), do: {:ok, v}

      def decode(v) when is_binary(v) do
        if v in unquote(atom_strings) do
          {:ok, String.to_existing_atom(v)}
        else
          :error
        end
      end

      def decode(_), do: :error

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

  defp generate_struct(fields) do
    field_defaults = Enum.map(fields, fn {name, _type, opts} -> {name, opts[:default]} end)
    field_types_map = Enum.map(fields, fn {name, type, _opts} -> {name, type} end)
    field_names = Enum.map(fields, fn {name, _type, _opts} -> name end)

    quote do
      defstruct unquote(field_defaults)

      @_struct_field_types unquote(Macro.escape(field_types_map))

      @impl Plushie.Type
      def cast(v) when is_map(v) or (is_list(v) and is_tuple(hd(v))) do
        case Plushie.Type.cast_named_fields(@_struct_field_types, v) do
          {:ok, map} -> {:ok, Kernel.struct(__MODULE__, map)}
          :error -> :error
        end
      end

      def cast(_), do: :error

      @impl Plushie.Type
      def decode(v) when is_map(v) do
        case Plushie.Type.decode_named_fields(@_struct_field_types, v) do
          {:ok, map} -> {:ok, Kernel.struct(__MODULE__, map)}
          :error -> :error
        end
      end

      def decode(v), do: cast(v)

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
      def encode(%__MODULE__{} = value) do
        value
        |> Map.take(unquote(field_names))
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new(fn {k, v} -> {k, Plushie.Type.encode_value(v)} end)
      end

      @impl Plushie.Type
      def fields, do: unquote(Macro.escape(field_types_map))
    end
  end

  # -- Union code generation ---------------------------------------------------

  defp generate_union(variants) do
    quote do
      @_union_variants unquote(Macro.escape(variants))

      @impl Plushie.Type
      def cast(value), do: Plushie.Type.cast_union_variants(@_union_variants, value)

      @impl Plushie.Type
      def decode(value), do: Plushie.Type.decode_union_variants(@_union_variants, value)

      @impl Plushie.Type
      def typespec, do: Plushie.Type.union_typespec(@_union_variants)
    end
  end
end
