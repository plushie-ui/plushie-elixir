defmodule Plushie.Type.Theme do
  @moduledoc """
  Built-in iced themes and custom palette support.

  Each built-in theme is an atom that maps to the corresponding `iced::Theme`
  variant on the Rust side. Custom themes are plain maps that the renderer
  parses into an `iced::Theme::custom()` palette.

  ## Extended palette shade overrides

  Custom themes automatically generate shade variants (strong, weak, etc.)
  from the six core palette colors using iced's Oklch-based algorithm. If
  you need precise control over specific shades, you can override them with
  flat keys in the theme map. Shade overrides only apply to custom themes --
  built-in themes are not affected.

  Each shade key targets a specific `Pair` (background color + text color)
  in the extended palette. Append `_text` to any shade key to override
  the text color for that shade.

  ### Color families (base, weak, strong)

  `primary`, `success`, `warning`, `danger` are core palette seeds
  (set via `custom/2`). `secondary` is auto-derived from `background`
  and `text` by iced's palette generator.

  All five families support shade overrides: `{family}_base`,
  `{family}_weak`, `{family}_strong`, plus `_text` variants.

  ### Background family (8 levels)

  `background_base`, `background_weakest`, `background_weaker`,
  `background_weak`, `background_neutral`, `background_strong`,
  `background_stronger`, `background_strongest`, plus `_text` variants.

  ### Example

      # Custom theme with shade overrides
      theme = %{
        name: "my-theme",
        background: "#1a1a2e",
        text: "#e0e0e0",
        primary: "#0f3460",
        primary_strong: "#1a5276",
        primary_strong_text: "#ffffff",
        background_weakest: "#0d0d1a"
      }

  Any shade key you omit keeps the auto-generated value.
  """

  @themes [
    :light,
    :dark,
    :dracula,
    :nord,
    :solarized_light,
    :solarized_dark,
    :gruvbox_light,
    :gruvbox_dark,
    :catppuccin_latte,
    :catppuccin_frappe,
    :catppuccin_macchiato,
    :catppuccin_mocha,
    :tokyo_night,
    :tokyo_night_storm,
    :tokyo_night_light,
    :kanagawa_wave,
    :kanagawa_dragon,
    :kanagawa_lotus,
    :moonfly,
    :nightfly,
    :oxocarbon,
    :ferra
  ]

  @type builtin :: unquote(Enum.reduce(@themes, &{:|, [], [&1, &2]}))

  use Plushie.Type

  @type t :: builtin() | :system | map()

  @doc """
  Validates a theme value.

  Accepts built-in theme atoms, `:system`, or a custom theme map
  (a map with at least a `:name` key).

  ## Examples

      iex> Plushie.Type.Theme.cast(:dark)
      {:ok, :dark}

      iex> Plushie.Type.Theme.cast(:system)
      {:ok, :system}

      iex> Plushie.Type.Theme.cast(%{name: "custom"})
      {:ok, %{name: "custom"}}

      iex> Plushie.Type.Theme.cast(:bogus)
      :error
  """
  @impl Plushie.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(:system), do: {:ok, :system}
  def cast(v) when v in @themes, do: {:ok, v}
  def cast(%{name: _} = map), do: {:ok, map}
  def cast(_), do: :error

  @impl Plushie.Type
  def typespec do
    quote do: atom() | map()
  end

  @impl Plushie.Type
  def guard(var) do
    quote do: is_atom(unquote(var)) or is_map(unquote(var))
  end

  @doc """
  Returns the list of all known built-in theme atoms.
  """
  @spec builtin_themes() :: [atom()]
  def builtin_themes, do: @themes

  @doc """
  Build a custom theme palette map.

  The returned map is passed through to the Rust renderer, which uses it to
  construct an `iced::Theme::custom()` with a modified `Palette`.

  ## Options

    * `:base`       - built-in theme atom to use as the palette starting point
    * `:background` - page background color
    * `:text`       - default text color
    * `:primary`    - primary accent color
    * `:success`    - success color
    * `:danger`     - danger color
    * `:warning`    - warning color

  All color values accept any form `Color.cast/1` supports (hex
  strings or named atoms). Shade override keys (e.g. `primary_strong`,
  `background_weakest`, `primary_strong_text`) are also accepted and
  cast as colors.

  Note: `:secondary` is not a core seed. It is auto-derived from
  `:background` and `:text` by iced's palette generator. To customize
  the secondary palette, use shade overrides: `secondary_base`,
  `secondary_weak`, `secondary_strong` (plus `_text` variants).

  Unknown keys raise `ArgumentError`. Use `valid_custom_keys/0` for
  the complete set.

  ## Examples

      iex> Plushie.Type.Theme.custom("Tokyo Remix", primary: "#7aa2f7", danger: "#f7768e")
      %{name: "Tokyo Remix", primary: "#7aa2f7", danger: "#f7768e"}

      iex> Plushie.Type.Theme.custom("Nord+", base: :nord, primary: "#88c0d0")
      %{name: "Nord+", base: "nord", primary: "#88c0d0"}
  """
  @spec custom(name :: String.t(), opts :: keyword()) :: map()
  def custom(name, opts \\ []) when is_binary(name) and is_list(opts) do
    {base, opts} = Keyword.pop(opts, :base)
    validate_custom_keys!(opts)

    result = %{name: name}
    result = maybe_put(result, :base, encode_base(base))

    Enum.reduce(opts, result, fn {key, value}, acc ->
      Map.put(acc, key, elem(Plushie.Type.Color.cast(value), 1))
    end)
  end

  # -- Valid custom theme keys -------------------------------------------------

  # Core palette seeds.
  @core_seeds [:background, :text, :primary, :success, :danger, :warning]

  # Color families with base/weak/strong shades.
  @color_families [:primary, :secondary, :success, :warning, :danger]

  # Background has 8 shade levels.
  @background_shades [
    :background_base,
    :background_weakest,
    :background_weaker,
    :background_weak,
    :background_neutral,
    :background_strong,
    :background_stronger,
    :background_strongest
  ]

  # Generate all shade override keys: {family}_{shade} + {family}_{shade}_text
  @color_shade_keys for family <- @color_families,
                        shade <- [:base, :weak, :strong],
                        suffix <- ["", "_text"],
                        do: :"#{family}_#{shade}#{suffix}"

  @background_shade_keys for shade <- @background_shades,
                             suffix <- ["", "_text"],
                             do: :"#{shade}#{suffix}"

  @valid_custom_keys MapSet.new(@core_seeds ++ @color_shade_keys ++ @background_shade_keys)

  @doc """
  Returns the set of valid keys for `custom/2` (excluding `:base`, which
  is handled separately).
  """
  @spec valid_custom_keys() :: MapSet.t(atom())
  def valid_custom_keys, do: @valid_custom_keys

  # -- Private ----------------------------------------------------------------

  defp validate_custom_keys!(opts) do
    Enum.each(opts, fn {key, _value} ->
      unless MapSet.member?(@valid_custom_keys, key) do
        raise ArgumentError,
              "unknown key #{inspect(key)} in Theme.custom/2. " <>
                "Valid keys: :base, #{inspect_valid_keys()}"
      end
    end)
  end

  defp inspect_valid_keys do
    @valid_custom_keys
    |> MapSet.to_list()
    |> Enum.sort()
    |> Enum.map_join(", ", &inspect/1)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp encode_base(nil), do: nil
  defp encode_base(theme) when theme in @themes, do: Atom.to_string(theme)
  defp encode_base(str) when is_binary(str), do: str
end
