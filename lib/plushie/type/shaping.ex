defmodule Plushie.Type.Shaping do
  @moduledoc """
  Text shaping strategy for the text `shaping` prop.

  Maps to iced's `text::Shaping` enum.
  """

  @type t :: :basic | :advanced | :auto

  @valid [:basic, :advanced, :auto]

  @doc """
  Encodes a shaping value to the wire format.

  ## Examples

      iex> Plushie.Type.Shaping.encode(:basic)
      "basic"

      iex> Plushie.Type.Shaping.encode(:advanced)
      "advanced"

      iex> Plushie.Type.Shaping.encode(:auto)
      "auto"
  """
  @spec encode(shaping :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
