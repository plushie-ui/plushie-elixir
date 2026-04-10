defmodule Plushie.Type.Composite do
  @moduledoc """
  Behaviour for composite type modules.

  Composite types are parameterized by a spec that describes their
  inner structure (e.g., the element type for lists, the field specs
  for maps). Each composite module implements this behaviour to
  handle casting, typespec generation, guards, and display for its
  specific parameterization.

  Callbacks that recurse into inner types receive a resolver function
  from the caller, keeping composite modules decoupled from the type
  resolution system.

  ## Implementations

    - `Plushie.Type.Composite.Enum` - `{:enum, [atoms]}`
    - `Plushie.Type.Composite.List` - `{:list, inner_type}`
    - `Plushie.Type.Composite.Map` - `{:map, {key_type, val_type}}` or `{:map, [name: type]}`
    - `Plushie.Type.Composite.Tuple` - `{:tuple, [types]}`
    - `Plushie.Type.Composite.Union` - `{:union, [types]}`
  """

  @type spec :: term()

  @doc "Casts a user-facing value against the composite spec."
  @callback cast(spec(), term()) :: {:ok, term()} | :error

  @doc "Decodes a wire-format value against the composite spec."
  @callback decode(spec(), term()) :: {:ok, term()} | :error

  @doc "Returns quoted typespec AST for the canonical form. The resolver maps inner type refs to their AST."
  @callback typespec(spec(), type_resolver :: (term() -> Macro.t())) :: Macro.t()

  @doc "Returns quoted typespec AST for accepted input forms. Defaults to typespec/2."
  @callback castable(spec(), type_resolver :: (term() -> Macro.t())) :: Macro.t()

  @doc "Returns a quoted guard expression, or nil if no guard applies."
  @callback guard(spec(), var :: Macro.t()) :: Macro.t() | nil

  @doc "Returns a human-readable type string for documentation."
  @callback display_string(spec(), string_resolver :: (term() -> String.t())) :: String.t()

  @doc "Returns true if the spec is structurally valid."
  @callback valid_spec?(spec(), checker :: (term() -> boolean())) :: boolean()

  @optional_callbacks [castable: 2, decode: 2]
end
