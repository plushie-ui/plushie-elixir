defmodule Julep.Iced.Position do
  @moduledoc """
  Tooltip position values matching iced's tooltip positioning options.

  Supported atoms: `:top`, `:bottom`, `:left`, `:right`, `:follow_cursor`.
  """

  @type t :: :top | :bottom | :left | :right | :follow_cursor

  @valid [:top, :bottom, :left, :right, :follow_cursor]

  @doc """
  Encodes a position value to the wire format.

  ## Examples

      iex> Julep.Iced.Position.encode(:top)
      "top"

      iex> Julep.Iced.Position.encode(:bottom)
      "bottom"

      iex> Julep.Iced.Position.encode(:left)
      "left"

      iex> Julep.Iced.Position.encode(:right)
      "right"

      iex> Julep.Iced.Position.encode(:follow_cursor)
      "follow_cursor"
  """
  @spec encode(position :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
