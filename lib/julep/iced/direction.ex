defmodule Julep.Iced.Direction do
  @moduledoc """
  Direction values matching iced's horizontal and vertical orientation.

  Supported atoms: `:horizontal`, `:vertical`.
  """

  @type t :: :horizontal | :vertical

  @valid [:horizontal, :vertical]

  @doc """
  Encodes a direction value to the wire format.

  ## Examples

      iex> Julep.Iced.Direction.encode(:horizontal)
      "horizontal"

      iex> Julep.Iced.Direction.encode(:vertical)
      "vertical"
  """
  @spec encode(direction :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
