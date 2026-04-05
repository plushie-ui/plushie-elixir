defmodule Plushie.Type.Key do
  @moduledoc """
  Event field type for keyboard key names.

  Parses wire-format key name strings (PascalCase, e.g. `"ArrowRight"`,
  `"Escape"`) into Elixir atoms (`:arrow_right`, `:escape`). Single
  character keys pass through as strings (`"a"`, `"1"`).

  Delegates to `Plushie.Protocol.Keys.parse_key/1` for the actual mapping.

  ## Examples

      iex> Plushie.Type.Key.parse("Escape")
      {:ok, :escape}

      iex> Plushie.Type.Key.parse("a")
      {:ok, "a"}

      iex> Plushie.Type.Key.parse(nil)
      :error
  """

  @behaviour Plushie.Type

  @spec parse(value :: term()) :: {:ok, atom() | String.t()} | :error
  def parse(value) when is_binary(value) do
    {:ok, Plushie.Protocol.Keys.parse_key(value)}
  end

  def parse(_), do: :error

  @impl Plushie.Type
  def cast(value), do: parse(value)

  @impl Plushie.Type
  def typespec do
    quote do: atom() | String.t()
  end
end
