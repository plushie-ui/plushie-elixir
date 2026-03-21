defmodule Plushie.Type.Position do
  @moduledoc """
  Placement value for the tooltip `position` prop.

  Maps to iced's `tooltip::Position` enum.
  """

  @type t :: :top | :bottom | :left | :right | :follow_cursor

  @valid [:top, :bottom, :left, :right, :follow_cursor]

  @doc """
  Encodes a position value to the wire format.

  ## Examples

      iex> Plushie.Type.Position.encode(:top)
      "top"

      iex> Plushie.Type.Position.encode(:bottom)
      "bottom"

      iex> Plushie.Type.Position.encode(:left)
      "left"

      iex> Plushie.Type.Position.encode(:right)
      "right"

      iex> Plushie.Type.Position.encode(:follow_cursor)
      "follow_cursor"
  """
  @spec encode(position :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
