defmodule Toddy.Type.Anchor do
  @moduledoc """
  Anchor values for the scrollbar `alignment` prop.

  Maps to iced's `scrollable::Anchor` enum.
  """

  @type t :: :start | :end

  @valid [:start, :end]

  @doc """
  Encodes an anchor value to the wire format.

  ## Examples

      iex> Toddy.Type.Anchor.encode(:start)
      "start"

      iex> Toddy.Type.Anchor.encode(:end)
      "end"
  """
  @spec encode(anchor :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
