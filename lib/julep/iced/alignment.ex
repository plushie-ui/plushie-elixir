defmodule Julep.Iced.Alignment do
  @moduledoc """
  Alignment values matching iced's horizontal and vertical alignment enums.

  Supported atoms: `:start`, `:center`, `:end`.
  """

  @type t :: :start | :center | :end

  @valid [:start, :center, :end]

  @doc """
  Encodes an alignment value to the wire format.

  ## Examples

      iex> Julep.Iced.Alignment.encode(:start)
      "start"

      iex> Julep.Iced.Alignment.encode(:center)
      "center"

      iex> Julep.Iced.Alignment.encode(:end)
      "end"
  """
  @spec encode(alignment :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
