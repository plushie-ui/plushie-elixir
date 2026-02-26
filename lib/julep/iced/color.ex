defmodule Julep.Iced.Color do
  @moduledoc """
  Color type for iced widget properties.

  The renderer accepts two color formats:

  - Hex string: `"#rrggbb"` or `"#rrggbbaa"`.
  - RGBA map: `%{r: 0.5, g: 0.5, b: 0.5, a: 1.0}` (floats 0.0-1.0).

  The constructors in this module produce one of these formats.

  ## Examples

      Julep.Iced.Color.from_rgb(255, 128, 0)
      #=> %{r: 1.0, g: 0.502, b: 0.0, a: 1.0}

      Julep.Iced.Color.from_hex("ff8800")
      #=> "#ff8800"

      Julep.Iced.Color.black()
      #=> "#000000"
  """

  @type t :: String.t() | {float(), float(), float()} | {float(), float(), float(), float()}

  @doc "Creates an RGBA color map from 0-255 RGB values."
  @spec from_rgb(number(), number(), number()) :: map()
  def from_rgb(r, g, b) when is_number(r) and is_number(g) and is_number(b) do
    %{r: r / 255, g: g / 255, b: b / 255, a: 1.0}
  end

  @doc "Creates an RGBA color map from 0-255 RGB values with an alpha channel (0.0-1.0)."
  @spec from_rgba(number(), number(), number(), float()) :: map()
  def from_rgba(r, g, b, a) when is_number(r) and is_number(g) and is_number(b) and is_number(a) do
    %{r: r / 255, g: g / 255, b: b / 255, a: a}
  end

  @doc "Creates a hex color string from a hex string (with or without leading #)."
  @spec from_hex(String.t()) :: String.t()
  def from_hex("#" <> hex), do: from_hex(hex)

  def from_hex(hex) when byte_size(hex) == 6 do
    "#" <> hex
  end

  def from_hex(hex) when byte_size(hex) == 8 do
    "#" <> hex
  end

  @doc "Returns black as a hex string."
  @spec black() :: String.t()
  def black, do: "#000000"

  @doc "Returns white as a hex string."
  @spec white() :: String.t()
  def white, do: "#ffffff"

  @doc "Returns fully transparent black as an RGBA map."
  @spec transparent() :: map()
  def transparent, do: %{r: 0.0, g: 0.0, b: 0.0, a: 0.0}

  @doc "Encodes a color value to the wire format."
  @spec encode(String.t() | map()) :: String.t() | map()
  def encode(color) when is_binary(color), do: color
  def encode(%{r: _, g: _, b: _, a: _} = color), do: color
  def encode(%{r: r, g: g, b: b}), do: %{r: r, g: g, b: b, a: 1.0}
end
