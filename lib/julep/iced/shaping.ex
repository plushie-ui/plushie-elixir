defmodule Julep.Iced.Shaping do
  @moduledoc """
  Text shaping modes matching iced's text shaping options.

  Supported atoms: `:basic`, `:advanced`, `:auto`.
  """

  @type t :: :basic | :advanced | :auto

  @valid [:basic, :advanced, :auto]

  @doc """
  Encodes a shaping value to the wire format.

  ## Examples

      iex> Julep.Iced.Shaping.encode(:basic)
      "basic"

      iex> Julep.Iced.Shaping.encode(:advanced)
      "advanced"

      iex> Julep.Iced.Shaping.encode(:auto)
      "auto"
  """
  @spec encode(shaping :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
