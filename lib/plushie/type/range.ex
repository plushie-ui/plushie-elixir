defmodule Plushie.Type.Range do
  @moduledoc """
  Validates `{min, max}` numeric range tuples.

  Used by slider and progress bar widgets for the value range.
  """

  @behaviour Plushie.Type

  @type t :: {number(), number()}

  @doc """
  Validates a `{min, max}` range tuple.

  ## Examples

      iex> Plushie.Type.Range.cast({0, 100})
      {:ok, {0, 100}}

      iex> Plushie.Type.Range.cast({-1.0, 1.0})
      {:ok, {-1.0, 1.0}}

      iex> Plushie.Type.Range.cast(:nope)
      :error
  """
  @impl Plushie.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast({min, max}) when is_number(min) and is_number(max), do: {:ok, {min, max}}
  def cast(_), do: :error

  @impl Plushie.Type
  def typespec do
    quote do: {number(), number()}
  end

  @impl Plushie.Type
  def guard(var) do
    quote do: is_tuple(unquote(var)) and tuple_size(unquote(var)) == 2
  end
end
