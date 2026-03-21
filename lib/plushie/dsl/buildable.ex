defmodule Plushie.DSL.Buildable do
  @moduledoc """
  Behaviour for types that participate in the Plushie DSL block-form pattern.

  Any struct whose values can be constructed via do-block declarations in
  the DSL should implement this behaviour. The DSL block interpreter uses
  these callbacks to:

  - Validate field names at compile time (`__field_keys__/0`)
  - Resolve nested struct types for recursive do-blocks (`__field_types__/0`)
  - Construct the struct from keyword options at runtime (`from_opts/1`)

  ## Example

      defmodule MyType do
        @behaviour Plushie.DSL.Buildable

        defstruct [:name, :size]

        @impl true
        def from_opts(opts), do: %__MODULE__{name: opts[:name], size: opts[:size]}

        @impl true
        def __field_keys__, do: ~w(name size)a

        @impl true
        def __field_types__, do: %{}
      end
  """

  @doc "Constructs the struct from a keyword list. Should validate unknown keys."
  @callback from_opts(opts :: keyword()) :: term()

  @doc "Returns the list of valid field name atoms for this struct."
  @callback __field_keys__() :: [atom()]

  @doc "Returns a map of field names to struct modules for nested do-block resolution."
  @callback __field_types__() :: %{atom() => module()}
end
