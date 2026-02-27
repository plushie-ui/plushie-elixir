defmodule Julep.Iced.Anchor do
  @moduledoc """
  Anchor positions for scrollbar placement.

  Supported atoms: `:start`, `:end`.
  """

  @type t :: :start | :end

  @valid [:start, :end]

  @doc """
  Encodes an anchor value to the wire format.

  ## Examples

      iex> Julep.Iced.Anchor.encode(:start)
      "start"

      iex> Julep.Iced.Anchor.encode(:end)
      "end"
  """
  @spec encode(anchor :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
