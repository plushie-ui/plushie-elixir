defmodule Plushie.Type.Alignment do
  @moduledoc """
  Alignment values for `align_x` and `align_y` widget props.

  Horizontal: `:left`, `:center`, `:right`.
  Vertical: `:top`, `:center`, `:bottom`.
  """

  @valid [:left, :center, :right, :top, :bottom]

  @type horizontal :: :left | :center | :right
  @type vertical :: :top | :center | :bottom
  @type t :: horizontal() | vertical()

  @doc """
  Encodes an alignment value to the wire format.

  ## Examples

      iex> Plushie.Type.Alignment.encode(:left)
      "left"

      iex> Plushie.Type.Alignment.encode(:center)
      "center"

      iex> Plushie.Type.Alignment.encode(:right)
      "right"

      iex> Plushie.Type.Alignment.encode(:top)
      "top"

      iex> Plushie.Type.Alignment.encode(:bottom)
      "bottom"
  """
  @spec encode(alignment :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
