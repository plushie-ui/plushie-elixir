defmodule Toddy.Iced.Length do
  @moduledoc """
  Size value for the `width` and `height` props on most widgets.

  Maps to iced's `Length` enum. Accepts `:fill`, `:shrink`,
  `{:fill_portion, n}`, or a numeric pixel value.
  """

  @type t :: :fill | :shrink | {:fill_portion, pos_integer()} | number()

  @doc """
  Encodes a length value to the wire format expected by the renderer.

  ## Examples

      iex> Toddy.Iced.Length.encode(:fill)
      "fill"

      iex> Toddy.Iced.Length.encode(:shrink)
      "shrink"

      iex> Toddy.Iced.Length.encode({:fill_portion, 3})
      %{"fill_portion" => 3}

      iex> Toddy.Iced.Length.encode(200)
      200
  """
  @spec encode(length :: t()) :: String.t() | number() | map()
  def encode(:fill), do: "fill"
  def encode(:shrink), do: "shrink"
  def encode({:fill_portion, n}) when is_integer(n) and n > 0, do: %{"fill_portion" => n}

  def encode(n) when is_number(n) and n < 0 do
    raise ArgumentError, "length must be non-negative, got: #{n}"
  end

  def encode(n) when is_number(n), do: n
end
