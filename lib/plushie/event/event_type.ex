defmodule Plushie.Event.EventType do
  @moduledoc """
  Behaviour for custom event field types.

  Event declarations use type identifiers to describe the shape of event
  data. Built-in atomic types (`:number`, `:string`, `:boolean`, `:any`)
  are handled implicitly. Module types implement this behaviour to provide
  custom parsing from wire-format values to Elixir types.

  ## Built-in atomic types

  These types pass through with validation only (no transformation):

  - `:number` -- integer or float
  - `:string` -- binary
  - `:boolean` -- true or false
  - `:any` -- any term, no validation

  ## Module types

  Any module that implements this behaviour can be used as a type in
  event declarations. The module must define `parse/1`, which transforms
  a wire-format value into an Elixir value.

  ## Example

      defmodule MyApp.Direction do
        @behaviour Plushie.EventType

        @impl true
        def parse("up"), do: {:ok, :up}
        def parse("down"), do: {:ok, :down}
        def parse("left"), do: {:ok, :left}
        def parse("right"), do: {:ok, :right}
        def parse(_), do: :error
      end

  Then in an event declaration:

      event :swipe, data: [direction: MyApp.Direction]
  """

  @doc """
  Parses a wire-format value into an Elixir value.

  Returns `{:ok, parsed_value}` on success, or `:error` if the value
  cannot be parsed.
  """
  @callback parse(term()) :: {:ok, term()} | :error

  @builtin_atomic_types [:number, :string, :boolean, :any]

  @doc "Returns the list of built-in atomic type identifiers."
  @spec builtin_atomic_types() :: [atom()]
  def builtin_atomic_types, do: @builtin_atomic_types

  @doc """
  Returns true if the given type identifier is valid for event fields.

  Valid types are built-in atoms or modules implementing this behaviour.
  """
  @spec valid_type?(type :: term()) :: boolean()
  def valid_type?(type) when type in @builtin_atomic_types, do: true

  def valid_type?(type) when is_atom(type) do
    Code.ensure_loaded?(type) and function_exported?(type, :parse, 1)
  end

  def valid_type?(_), do: false

  @doc """
  Parses a value according to a type identifier.

  For built-in atomic types, validates the value matches the expected
  type. For module types, delegates to `module.parse/1`.

  The `:string` type accepts `nil` in addition to binaries, since
  wire-format event fields may be absent (decoded as nil).

  Returns `{:ok, value}` on success, `:error` on failure.
  """
  @spec parse_field(type :: atom(), value :: term()) :: {:ok, term()} | :error
  def parse_field(:any, value), do: {:ok, value}
  def parse_field(:number, value) when is_number(value), do: {:ok, value}
  def parse_field(:number, _), do: :error
  def parse_field(:string, value) when is_binary(value), do: {:ok, value}
  def parse_field(:string, nil), do: {:ok, nil}
  def parse_field(:string, _), do: :error
  def parse_field(:boolean, value) when is_boolean(value), do: {:ok, value}
  def parse_field(:boolean, _), do: :error
  def parse_field(module, value) when is_atom(module), do: module.parse(value)
end
