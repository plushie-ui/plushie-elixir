defmodule Julep.Iced.Wrapping do
  @moduledoc """
  Text wrapping modes matching iced's text wrapping options.

  Supported atoms: `:none`, `:word`, `:glyph`, `:word_or_glyph`.
  """

  @type t :: :none | :word | :glyph | :word_or_glyph

  @valid [:none, :word, :glyph, :word_or_glyph]

  @doc """
  Encodes a wrapping value to the wire format.

  ## Examples

      iex> Julep.Iced.Wrapping.encode(:none)
      "none"

      iex> Julep.Iced.Wrapping.encode(:word)
      "word"

      iex> Julep.Iced.Wrapping.encode(:glyph)
      "glyph"

      iex> Julep.Iced.Wrapping.encode(:word_or_glyph)
      "word_or_glyph"
  """
  @spec encode(wrapping :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
