defmodule Toddy.Type.FilterMethod do
  @moduledoc """
  Interpolation mode for the image `filter_method` prop.

  Maps to iced's `image::FilterMethod` enum.
  """

  @type t :: :nearest | :linear

  @valid [:nearest, :linear]

  @doc """
  Encodes a filter method value to the wire format.

  ## Examples

      iex> Toddy.Type.FilterMethod.encode(:nearest)
      "nearest"

      iex> Toddy.Type.FilterMethod.encode(:linear)
      "linear"
  """
  @spec encode(filter_method :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
