defmodule Plushie.Type.Length do
  @moduledoc """
  Size value for the `width` and `height` props on most widgets.

  Maps to iced's `Length` enum. Accepts `:fill`, `:shrink`,
  `{:fill_portion, n}`, or a numeric pixel value.
  """

  use Plushie.Type

  @type t :: :fill | :shrink | {:fill_portion, pos_integer()} | number()

  @doc """
  Validates a length value.

  ## Examples

      iex> Plushie.Type.Length.cast(:fill)
      {:ok, :fill}

      iex> Plushie.Type.Length.cast(:shrink)
      {:ok, :shrink}

      iex> Plushie.Type.Length.cast({:fill_portion, 3})
      {:ok, {:fill_portion, 3}}

      iex> Plushie.Type.Length.cast(200)
      {:ok, 200}

      iex> Plushie.Type.Length.cast(:bogus)
      :error
  """
  @impl Plushie.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(:fill), do: {:ok, :fill}
  def cast(:shrink), do: {:ok, :shrink}

  def cast({:fill_portion, n}) when is_integer(n) and n > 0,
    do: {:ok, {:fill_portion, n}}

  def cast(n) when is_number(n) and n >= 0, do: {:ok, n}
  def cast(_), do: :error

  @impl Plushie.Type
  def typespec do
    quote do: :fill | :shrink | {:fill_portion, pos_integer()} | number()
  end

  @impl Plushie.Type
  def guard(var) do
    quote do
      unquote(var) in [:fill, :shrink] or is_number(unquote(var)) or
        (is_tuple(unquote(var)) and tuple_size(unquote(var)) == 2)
    end
  end

  @doc """
  Encodes a length value to the wire format expected by the renderer.

  ## Examples

      iex> Plushie.Type.Length.encode(:fill)
      "fill"

      iex> Plushie.Type.Length.encode(:shrink)
      "shrink"

      iex> Plushie.Type.Length.encode({:fill_portion, 3})
      %{fill_portion: 3}

      iex> Plushie.Type.Length.encode(200)
      200
  """
  @impl Plushie.Type
  @spec encode(length :: t()) :: String.t() | number() | map()
  def encode(:fill), do: "fill"
  def encode(:shrink), do: "shrink"
  def encode({:fill_portion, n}) when is_integer(n) and n > 0, do: %{fill_portion: n}

  def encode(n) when is_number(n) and n < 0 do
    raise ArgumentError, "length must be non-negative, got: #{n}"
  end

  def encode(n) when is_number(n), do: n
end
