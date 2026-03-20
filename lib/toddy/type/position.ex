defmodule Toddy.Type.Position do
  @moduledoc """
  Placement value for the tooltip `position` prop.

  Maps to iced's `tooltip::Position` enum.
  """

  @type t :: :top | :bottom | :left | :right | :follow_cursor

  @valid [:top, :bottom, :left, :right, :follow_cursor]

  @doc """
  Encodes a position value to the wire format.

  ## Examples

      iex> Toddy.Type.Position.encode(:top)
      "top"

      iex> Toddy.Type.Position.encode(:bottom)
      "bottom"

      iex> Toddy.Type.Position.encode(:left)
      "left"

      iex> Toddy.Type.Position.encode(:right)
      "right"

      iex> Toddy.Type.Position.encode(:follow_cursor)
      "follow_cursor"
  """
  @spec encode(position :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
