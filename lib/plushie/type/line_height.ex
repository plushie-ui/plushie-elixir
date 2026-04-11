defmodule Plushie.Type.LineHeight do
  @moduledoc """
  Line height for text widgets.

  Accepts three forms:

    - A number (relative multiplier, e.g. `1.5`)
    - `%{relative: n}` for explicit relative line height
    - `%{absolute: n}` for absolute pixel line height

  Numbers are passed through as-is (the renderer interprets plain
  numbers as relative multipliers). Maps are passed through unchanged
  so the renderer can distinguish the two explicit forms.

  ## Examples

      iex> Plushie.Type.LineHeight.cast(1.5)
      {:ok, 1.5}

      iex> Plushie.Type.LineHeight.cast(%{relative: 1.5})
      {:ok, %{relative: 1.5}}

      iex> Plushie.Type.LineHeight.cast(%{absolute: 20})
      {:ok, %{absolute: 20}}

      iex> Plushie.Type.LineHeight.cast(:bogus)
      :error
  """

  use Plushie.Type

  @type t :: number() | %{relative: number()} | %{absolute: number()}

  @doc """
  Validates a line height value.

  ## Examples

      iex> Plushie.Type.LineHeight.cast(1.0)
      {:ok, 1.0}

      iex> Plushie.Type.LineHeight.cast(2)
      {:ok, 2}

      iex> Plushie.Type.LineHeight.cast(%{relative: 1.2})
      {:ok, %{relative: 1.2}}

      iex> Plushie.Type.LineHeight.cast(%{absolute: 24})
      {:ok, %{absolute: 24}}

      iex> Plushie.Type.LineHeight.cast("bad")
      :error
  """
  @impl Plushie.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(n) when is_number(n), do: {:ok, n}
  def cast(%{relative: n}) when is_number(n), do: {:ok, %{relative: n}}
  def cast(%{absolute: n}) when is_number(n), do: {:ok, %{absolute: n}}
  def cast(_), do: :error

  @impl Plushie.Type
  def typespec do
    quote do: number() | %{relative: number()} | %{absolute: number()}
  end

  @impl Plushie.Type
  def guard(var) do
    quote do: is_number(unquote(var)) or is_map(unquote(var))
  end

  @doc """
  Encodes a line height for the wire format.

  Numbers and maps pass through unchanged.

  ## Examples

      iex> Plushie.Type.LineHeight.encode(1.5)
      1.5

      iex> Plushie.Type.LineHeight.encode(%{relative: 1.2})
      %{relative: 1.2}

      iex> Plushie.Type.LineHeight.encode(%{absolute: 20})
      %{absolute: 20}
  """
  @impl Plushie.Type
  @spec encode(line_height :: t()) :: t()
  def encode(n) when is_number(n), do: n
  def encode(%{relative: _} = map), do: map
  def encode(%{absolute: _} = map), do: map
end
