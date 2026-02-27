defmodule Julep.Iced.FilterMethod do
  @moduledoc """
  Image filter methods matching iced's image filtering options.

  Supported atoms: `:nearest`, `:linear`.
  """

  @type t :: :nearest | :linear

  @valid [:nearest, :linear]

  @doc """
  Encodes a filter method value to the wire format.

  ## Examples

      iex> Julep.Iced.FilterMethod.encode(:nearest)
      "nearest"

      iex> Julep.Iced.FilterMethod.encode(:linear)
      "linear"
  """
  @spec encode(filter_method :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
