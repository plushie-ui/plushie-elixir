defmodule Julep.Iced.Color do
  @moduledoc """
  Color type for iced widget properties.

  All colors are canonical hex strings: `"#rrggbb"` or `"#rrggbbaa"`.

  Use the constructors `from_rgb/3`, `from_rgba/4`, and `from_hex/1` to build
  colors. Use `cast/1` to normalize any supported input form (named atoms
  or hex strings) into a canonical hex string.

  ## Examples

      iex> Julep.Iced.Color.from_rgb(255, 128, 0)
      "#ff8000"

      iex> Julep.Iced.Color.from_hex("ff8800")
      "#ff8800"

      iex> Julep.Iced.Color.cast(:red)
      "#ff0000"
  """

  @type t :: String.t()

  @named_colors %{
    black: "#000000",
    white: "#ffffff",
    transparent: "#00000000",
    red: "#ff0000",
    green: "#00ff00",
    blue: "#0000ff",
    yellow: "#ffff00",
    cyan: "#00ffff",
    magenta: "#ff00ff",
    gray: "#808080",
    grey: "#808080"
  }

  @doc """
  Creates a hex color string from 0-255 RGB integer values.

  ## Examples

      iex> Julep.Iced.Color.from_rgb(0, 0, 0)
      "#000000"

      iex> Julep.Iced.Color.from_rgb(255, 255, 255)
      "#ffffff"

      iex> Julep.Iced.Color.from_rgb(255, 128, 0)
      "#ff8000"
  """
  @spec from_rgb(r :: integer(), g :: integer(), b :: integer()) :: t()
  def from_rgb(r, g, b) when is_integer(r) and is_integer(g) and is_integer(b) do
    "#" <> hex_byte(r) <> hex_byte(g) <> hex_byte(b)
  end

  @doc """
  Creates a hex color string with alpha from 0-255 RGB integers and a 0.0-1.0 alpha float.

  ## Examples

      iex> Julep.Iced.Color.from_rgba(255, 0, 0, 1.0)
      "#ff0000ff"

      iex> Julep.Iced.Color.from_rgba(0, 0, 0, 0.0)
      "#00000000"

      iex> Julep.Iced.Color.from_rgba(255, 128, 0, 0.5)
      "#ff800080"
  """
  @spec from_rgba(r :: integer(), g :: integer(), b :: integer(), a :: float()) :: t()
  def from_rgba(r, g, b, a)
      when is_integer(r) and is_integer(g) and is_integer(b) and is_number(a) do
    "#" <> hex_byte(r) <> hex_byte(g) <> hex_byte(b) <> hex_byte(round(a * 255))
  end

  @doc """
  Normalizes a hex string (with or without leading `#`) to canonical form.

  Downcases the hex digits for consistency.

  ## Examples

      iex> Julep.Iced.Color.from_hex("#FF8800")
      "#ff8800"

      iex> Julep.Iced.Color.from_hex("ff8800")
      "#ff8800"

      iex> Julep.Iced.Color.from_hex("#ff880080")
      "#ff880080"
  """
  @spec from_hex(hex :: String.t()) :: t()
  def from_hex("#" <> hex), do: from_hex(hex)

  def from_hex(hex) when byte_size(hex) == 6 do
    "#" <> String.downcase(hex)
  end

  def from_hex(hex) when byte_size(hex) == 8 do
    "#" <> String.downcase(hex)
  end

  @doc "Returns black as a hex string."
  @spec black() :: t()
  def black, do: "#000000"

  @doc "Returns white as a hex string."
  @spec white() :: t()
  def white, do: "#ffffff"

  @doc "Returns fully transparent black as a hex string."
  @spec transparent() :: t()
  def transparent, do: "#00000000"

  @doc """
  Normalizes any supported color input to a canonical hex string.

  Accepts:

  - Named atoms: `:black`, `:white`, `:transparent`, `:red`, `:green`, `:blue`,
    `:yellow`, `:cyan`, `:magenta`, `:gray` / `:grey`
  - Hex strings: `"#rrggbb"` or `"#rrggbbaa"` (passed through, downcased)

  Raises `ArgumentError` for unsupported atoms.

  ## Examples

      iex> Julep.Iced.Color.cast(:black)
      "#000000"

      iex> Julep.Iced.Color.cast(:transparent)
      "#00000000"

      iex> Julep.Iced.Color.cast("#FF0000")
      "#ff0000"
  """
  @spec cast(color :: atom() | String.t()) :: t()
  def cast(name) when is_atom(name) do
    case Map.fetch(@named_colors, name) do
      {:ok, hex} -> hex
      :error -> raise ArgumentError, "unknown color name: #{inspect(name)}"
    end
  end

  def cast("#" <> _ = hex), do: from_hex(hex)

  @doc """
  Encodes a color for the wire format. Identity since all colors are hex strings.

  ## Examples

      iex> Julep.Iced.Color.encode("#ff0000")
      "#ff0000"
  """
  @spec encode(color :: t()) :: t()
  def encode(color) when is_binary(color), do: color

  # Converts an integer 0-255 to a zero-padded two-character lowercase hex string.
  @spec hex_byte(value :: integer()) :: String.t()
  defp hex_byte(value) when value >= 0 and value <= 255 do
    value
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(2, "0")
  end
end
