defmodule Plushie.Type.Direction do
  @moduledoc """
  Orientation for the scrollable `direction` prop and rule widget.

  Maps to iced's horizontal/vertical axis variants.
  """

  @type t :: :horizontal | :vertical | :both

  @valid [:horizontal, :vertical, :both]

  @doc """
  Encodes a direction value to the wire format.

  ## Examples

      iex> Plushie.Type.Direction.encode(:horizontal)
      "horizontal"

      iex> Plushie.Type.Direction.encode(:vertical)
      "vertical"

      iex> Plushie.Type.Direction.encode(:both)
      "both"
  """
  @spec encode(direction :: t()) :: String.t()
  def encode(value) when value in @valid, do: Atom.to_string(value)
end
