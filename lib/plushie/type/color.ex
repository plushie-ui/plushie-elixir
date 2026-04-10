defmodule Plushie.Type.Color do
  @moduledoc """
  Color type for iced widget properties.

  All colors are canonical hex strings: `"#rrggbb"` or `"#rrggbbaa"`.

  Use the constructors `from_rgb/3`, `from_rgba/4`, and `from_hex/1` to build
  colors. Use `cast/1` to normalize any supported input form (named atoms,
  named strings, or hex strings) into a canonical hex string.

  All 148 CSS Color Module Level 4 named colors are supported, plus
  `:transparent`.

  ## Examples

      iex> Plushie.Type.Color.from_rgb(255, 128, 0)
      "#ff8000"

      iex> Plushie.Type.Color.from_hex("ff8800")
      "#ff8800"

      iex> Plushie.Type.Color.cast(:red)
      {:ok, "#ff0000"}

      iex> Plushie.Type.Color.cast(:cornflowerblue)
      {:ok, "#6495ed"}
  """

  @typedoc ~S'Canonical hex color string (`"#rrggbb"` or `"#rrggbbaa"`).'
  @type t :: String.t()

  # All 148 CSS Color Module Level 4 named colors plus transparent.
  # Sorted alphabetically for maintainability.
  @named_colors %{
    aliceblue: "#f0f8ff",
    antiquewhite: "#faebd7",
    aqua: "#00ffff",
    aquamarine: "#7fffd4",
    azure: "#f0ffff",
    beige: "#f5f5dc",
    bisque: "#ffe4c4",
    black: "#000000",
    blanchedalmond: "#ffebcd",
    blue: "#0000ff",
    blueviolet: "#8a2be2",
    brown: "#a52a2a",
    burlywood: "#deb887",
    cadetblue: "#5f9ea0",
    chartreuse: "#7fff00",
    chocolate: "#d2691e",
    coral: "#ff7f50",
    cornflowerblue: "#6495ed",
    cornsilk: "#fff8dc",
    crimson: "#dc143c",
    cyan: "#00ffff",
    darkblue: "#00008b",
    darkcyan: "#008b8b",
    darkgoldenrod: "#b8860b",
    darkgray: "#a9a9a9",
    darkgreen: "#006400",
    darkgrey: "#a9a9a9",
    darkkhaki: "#bdb76b",
    darkmagenta: "#8b008b",
    darkolivegreen: "#556b2f",
    darkorange: "#ff8c00",
    darkorchid: "#9932cc",
    darkred: "#8b0000",
    darksalmon: "#e9967a",
    darkseagreen: "#8fbc8f",
    darkslateblue: "#483d8b",
    darkslategray: "#2f4f4f",
    darkslategrey: "#2f4f4f",
    darkturquoise: "#00ced1",
    darkviolet: "#9400d3",
    deeppink: "#ff1493",
    deepskyblue: "#00bfff",
    dimgray: "#696969",
    dimgrey: "#696969",
    dodgerblue: "#1e90ff",
    firebrick: "#b22222",
    floralwhite: "#fffaf0",
    forestgreen: "#228b22",
    fuchsia: "#ff00ff",
    gainsboro: "#dcdcdc",
    ghostwhite: "#f8f8ff",
    gold: "#ffd700",
    goldenrod: "#daa520",
    gray: "#808080",
    green: "#008000",
    greenyellow: "#adff2f",
    grey: "#808080",
    honeydew: "#f0fff0",
    hotpink: "#ff69b4",
    indianred: "#cd5c5c",
    indigo: "#4b0082",
    ivory: "#fffff0",
    khaki: "#f0e68c",
    lavender: "#e6e6fa",
    lavenderblush: "#fff0f5",
    lawngreen: "#7cfc00",
    lemonchiffon: "#fffacd",
    lightblue: "#add8e6",
    lightcoral: "#f08080",
    lightcyan: "#e0ffff",
    lightgoldenrodyellow: "#fafad2",
    lightgray: "#d3d3d3",
    lightgreen: "#90ee90",
    lightgrey: "#d3d3d3",
    lightpink: "#ffb6c1",
    lightsalmon: "#ffa07a",
    lightseagreen: "#20b2aa",
    lightskyblue: "#87cefa",
    lightslategray: "#778899",
    lightslategrey: "#778899",
    lightsteelblue: "#b0c4de",
    lightyellow: "#ffffe0",
    lime: "#00ff00",
    limegreen: "#32cd32",
    linen: "#faf0e6",
    magenta: "#ff00ff",
    maroon: "#800000",
    mediumaquamarine: "#66cdaa",
    mediumblue: "#0000cd",
    mediumorchid: "#ba55d3",
    mediumpurple: "#9370db",
    mediumseagreen: "#3cb371",
    mediumslateblue: "#7b68ee",
    mediumspringgreen: "#00fa9a",
    mediumturquoise: "#48d1cc",
    mediumvioletred: "#c71585",
    midnightblue: "#191970",
    mintcream: "#f5fffa",
    mistyrose: "#ffe4e1",
    moccasin: "#ffe4b5",
    navajowhite: "#ffdead",
    navy: "#000080",
    oldlace: "#fdf5e6",
    olive: "#808000",
    olivedrab: "#6b8e23",
    orange: "#ffa500",
    orangered: "#ff4500",
    orchid: "#da70d6",
    palegoldenrod: "#eee8aa",
    palegreen: "#98fb98",
    paleturquoise: "#afeeee",
    palevioletred: "#db7093",
    papayawhip: "#ffefd5",
    peachpuff: "#ffdab9",
    peru: "#cd853f",
    pink: "#ffc0cb",
    plum: "#dda0dd",
    powderblue: "#b0e0e6",
    purple: "#800080",
    rebeccapurple: "#663399",
    red: "#ff0000",
    rosybrown: "#bc8f8f",
    royalblue: "#4169e1",
    saddlebrown: "#8b4513",
    salmon: "#fa8072",
    sandybrown: "#f4a460",
    seagreen: "#2e8b57",
    seashell: "#fff5ee",
    sienna: "#a0522d",
    silver: "#c0c0c0",
    skyblue: "#87ceeb",
    slateblue: "#6a5acd",
    slategray: "#708090",
    slategrey: "#708090",
    snow: "#fffafa",
    springgreen: "#00ff7f",
    steelblue: "#4682b4",
    tan: "#d2b48c",
    teal: "#008080",
    thistle: "#d8bfd8",
    tomato: "#ff6347",
    transparent: "#00000000",
    turquoise: "#40e0d0",
    violet: "#ee82ee",
    wheat: "#f5deb3",
    white: "#ffffff",
    whitesmoke: "#f5f5f5",
    yellow: "#ffff00",
    yellowgreen: "#9acd32"
  }

  # Downcased string -> hex lookup for cast/1 string support.
  @named_colors_by_string Map.new(@named_colors, fn {k, v} -> {Atom.to_string(k), v} end)

  @typedoc "Named CSS color atom (148 CSS Color Module Level 4 colors plus `:transparent`)."
  @type named :: unquote(Enum.reduce(Map.keys(@named_colors), &{:|, [], [&1, &2]}))

  @typedoc "Any value accepted by `cast/1`: hex string, short hex, named color atom, named color string, or float RGB/RGBA map."
  @type input ::
          named()
          | String.t()
          | %{r: float(), g: float(), b: float(), a: float()}
          | %{r: float(), g: float(), b: float()}

  @doc """
  Creates a hex color string from 0-255 RGB integer values.

  ## Examples

      iex> Plushie.Type.Color.from_rgb(0, 0, 0)
      "#000000"

      iex> Plushie.Type.Color.from_rgb(255, 255, 255)
      "#ffffff"

      iex> Plushie.Type.Color.from_rgb(255, 128, 0)
      "#ff8000"
  """
  @spec from_rgb(r :: integer(), g :: integer(), b :: integer()) :: t()
  def from_rgb(r, g, b) when is_integer(r) and is_integer(g) and is_integer(b) do
    "#" <> hex_byte(r) <> hex_byte(g) <> hex_byte(b)
  end

  @doc """
  Creates a hex color string with alpha from 0-255 RGB integers and a 0.0-1.0 alpha float.

  ## Examples

      iex> Plushie.Type.Color.from_rgba(255, 0, 0, 1.0)
      "#ff0000ff"

      iex> Plushie.Type.Color.from_rgba(0, 0, 0, 0.0)
      "#00000000"

      iex> Plushie.Type.Color.from_rgba(255, 128, 0, 0.5)
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

      iex> Plushie.Type.Color.from_hex("#FF8800")
      "#ff8800"

      iex> Plushie.Type.Color.from_hex("ff8800")
      "#ff8800"

      iex> Plushie.Type.Color.from_hex("#ff880080")
      "#ff880080"
  """
  @spec from_hex(hex :: String.t()) :: t()
  def from_hex("#" <> hex), do: from_hex(hex)

  def from_hex(<<r, g, b>> = hex) when byte_size(hex) == 3 do
    from_hex(<<r, r, g, g, b, b>>)
  end

  def from_hex(<<r, g, b, a>> = hex) when byte_size(hex) == 4 do
    from_hex(<<r, r, g, g, b, b, a, a>>)
  end

  def from_hex(hex) when byte_size(hex) == 6 do
    validate_hex_digits!(hex)
    "#" <> String.downcase(hex)
  end

  def from_hex(hex) when byte_size(hex) == 8 do
    validate_hex_digits!(hex)
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

  - Named atoms: all 148 CSS Color Module Level 4 named colors (e.g. `:red`,
    `:cornflowerblue`, `:rebeccapurple`) plus `:transparent`
  - Named strings: same names as atoms, case-insensitive (e.g. `"red"`,
    `"CornflowerBlue"`)
  - Hex strings: `"#rrggbb"`, `"#rrggbbaa"`, `"#rgb"`, `"#rgba"` (normalized
    to canonical 6/8-char lowercase hex)
  - Float RGBA map: `%{r: 1.0, g: 0.0, b: 0.0, a: 0.5}` (values clamped to 0.0-1.0)
  - Float RGB map: `%{r: 1.0, g: 0.0, b: 0.0}` (alpha defaults to 1.0)

  Raises `ArgumentError` for unsupported atoms.

  ## Examples

      iex> Plushie.Type.Color.cast(:black)
      {:ok, "#000000"}

      iex> Plushie.Type.Color.cast(:transparent)
      {:ok, "#00000000"}

      iex> Plushie.Type.Color.cast("#FF0000")
      {:ok, "#ff0000"}

      iex> Plushie.Type.Color.cast(:cornflowerblue)
      {:ok, "#6495ed"}

      iex> Plushie.Type.Color.cast("red")
      {:ok, "#ff0000"}

      iex> Plushie.Type.Color.cast("CornflowerBlue")
      {:ok, "#6495ed"}
  """
  use Plushie.Type

  @impl Plushie.Type
  @spec cast(color :: input()) :: {:ok, t()} | :error
  def cast(%{r: r, g: g, b: b, a: a})
      when is_number(r) and is_number(g) and is_number(b) and is_number(a) do
    {:ok, from_rgba(float_to_byte(r), float_to_byte(g), float_to_byte(b), clamp_float(a))}
  end

  def cast(%{r: r, g: g, b: b})
      when is_number(r) and is_number(g) and is_number(b) do
    {:ok, from_rgb(float_to_byte(r), float_to_byte(g), float_to_byte(b))}
  end

  def cast(name) when is_atom(name) do
    case Map.fetch(@named_colors, name) do
      {:ok, hex} -> {:ok, hex}
      :error -> :error
    end
  end

  def cast("#" <> _ = hex) do
    {:ok, from_hex(hex)}
  rescue
    ArgumentError -> :error
  end

  def cast(str) when is_binary(str) do
    case Map.fetch(@named_colors_by_string, String.downcase(str)) do
      {:ok, hex} ->
        {:ok, hex}

      :error ->
        {:ok, from_hex(str)}
    end
  rescue
    ArgumentError -> :error
  end

  def cast(_), do: :error

  @doc """
  Returns the map of all supported named colors.

  Keys are atoms, values are canonical hex strings.
  """
  @spec named_colors() :: %{atom() => t()}
  def named_colors, do: @named_colors

  @doc """
  Encodes a color for the wire format. Identity since all colors are hex strings.

  ## Examples

      iex> Plushie.Type.Color.encode("#ff0000")
      "#ff0000"
  """
  @impl Plushie.Type
  @spec encode(color :: t()) :: t()
  def encode(color) when is_binary(color), do: color

  # Converts a float 0.0-1.0 to an integer 0-255, clamping out-of-range values.
  defp float_to_byte(f), do: f |> clamp_float() |> Kernel.*(255) |> round()

  # Clamps a float to the 0.0-1.0 range.
  defp clamp_float(f) when f < 0.0, do: 0.0
  defp clamp_float(f) when f > 1.0, do: 1.0
  defp clamp_float(f), do: f

  # Converts an integer 0-255 to a zero-padded two-character lowercase hex string.
  @spec hex_byte(value :: integer()) :: String.t()
  defp hex_byte(value) when value >= 0 and value <= 255 do
    value
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(2, "0")
  end

  # -- Plushie.Type callbacks ----------------------------------------------------

  @doc false
  @impl Plushie.Type
  def typespec do
    quote do: String.t()
  end

  @doc false
  @impl Plushie.Type
  def castable do
    quote do: atom() | String.t() | map()
  end

  @doc false
  @impl Plushie.Type
  def guard(var) do
    quote do: is_binary(unquote(var))
  end

  # -- Private -----------------------------------------------------------------

  defp validate_hex_digits!(hex) do
    unless Regex.match?(~r/\A[0-9a-fA-F]+\z/, hex) do
      raise ArgumentError, "invalid hex color digits: #{inspect(hex)}"
    end
  end
end
