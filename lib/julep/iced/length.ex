defmodule Julep.Iced.Length do
  @moduledoc """
  Length values matching iced's `Length` enum.

  Supported forms:

  - `:fill` -- fill available space
  - `:shrink` -- use minimum required space
  - `{:fill_portion, n}` -- fill a weighted portion of available space
  - numeric (integer or float) -- fixed pixel value
  """

  @type t :: :fill | :shrink | {:fill_portion, pos_integer()} | number()

  @doc """
  Encodes a length value to the wire format expected by the renderer.

  ## Examples

      iex> Julep.Iced.Length.encode(:fill)
      "fill"

      iex> Julep.Iced.Length.encode(:shrink)
      "shrink"

      iex> Julep.Iced.Length.encode({:fill_portion, 3})
      %{"fill_portion" => 3}

      iex> Julep.Iced.Length.encode(200)
      200
  """
  @spec encode(t()) :: String.t() | number() | map()
  def encode(:fill), do: "fill"
  def encode(:shrink), do: "shrink"
  def encode({:fill_portion, n}) when is_integer(n) and n > 0, do: %{"fill_portion" => n}
  def encode(n) when is_number(n), do: n
end
