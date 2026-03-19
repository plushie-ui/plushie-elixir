defmodule Julep.Iced.Alignment do
  @moduledoc """
  Alignment values for `align_x` and `align_y` widget props.

  Horizontal: `:left`, `:center`, `:right` (aliases: `:start` = `:left`, `:end` = `:right`).
  Vertical: `:top`, `:center`, `:bottom` (aliases: `:start` = `:top`, `:end` = `:bottom`).
  """

  @valid [:left, :center, :right, :top, :bottom, :start, :end]

  @type horizontal :: :left | :center | :right | :start | :end
  @type vertical :: :top | :center | :bottom | :start | :end
  @type t :: horizontal() | vertical()

  @doc """
  Encodes an alignment value to the wire format.

  ## Examples

      iex> Julep.Iced.Alignment.encode(:left)
      "left"

      iex> Julep.Iced.Alignment.encode(:center)
      "center"

      iex> Julep.Iced.Alignment.encode(:right)
      "right"

      iex> Julep.Iced.Alignment.encode(:top)
      "top"

      iex> Julep.Iced.Alignment.encode(:bottom)
      "bottom"

      iex> Julep.Iced.Alignment.encode(:start)
      "start"

      iex> Julep.Iced.Alignment.encode(:end)
      "end"
  """
  @spec encode(alignment :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
