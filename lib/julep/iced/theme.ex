defmodule Julep.Iced.Theme do
  @moduledoc """
  Built-in iced themes and custom palette support.

  Each built-in theme is an atom that maps to the corresponding `iced::Theme`
  variant on the Rust side. Custom themes are plain maps that the renderer
  parses into an `iced::Theme::custom()` palette.
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

  @type t :: atom() | String.t() | map()

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

    * `:base`       - built-in theme name to use as the palette starting point
    * `:background` - hex color string, e.g. "#1a1b26"
    * `:text`       - hex color string
    * `:primary`    - hex color string
    * `:success`    - hex color string
    * `:danger`     - hex color string

  ## Examples

      iex> Julep.Iced.Theme.custom("Tokyo Remix", primary: "#7aa2f7", danger: "#f7768e")
      %{"name" => "Tokyo Remix", "primary" => "#7aa2f7", "danger" => "#f7768e"}

      iex> Julep.Iced.Theme.custom("Nord+", base: :nord, primary: "#88c0d0")
      %{"name" => "Nord+", "base" => "nord", "primary" => "#88c0d0"}
  """
  @spec custom(name :: String.t(), opts :: keyword()) :: map()
  def custom(name, opts \\ []) when is_binary(name) and is_list(opts) do
    %{"name" => name}
    |> maybe_put("base", encode_base(opts[:base]))
    |> maybe_put("background", opts[:background])
    |> maybe_put("text", opts[:text])
    |> maybe_put("primary", opts[:primary])
    |> maybe_put("success", opts[:success])
    |> maybe_put("danger", opts[:danger])
    |> maybe_put("warning", opts[:warning])
  end

  @doc """
  Encodes a theme to its wire-format representation.

  Built-in theme atoms are converted to PascalCase strings. Custom theme maps
  are passed through unchanged.

  ## Examples

      iex> Julep.Iced.Theme.encode(:dark)
      "Dark"

      iex> Julep.Iced.Theme.encode(:catppuccin_mocha)
      "CatppuccinMocha"

      iex> Julep.Iced.Theme.encode(%{"name" => "Mine", "primary" => "#ff0000"})
      %{"name" => "Mine", "primary" => "#ff0000"}
  """
  @spec encode(theme :: t()) :: String.t() | map()
  def encode(theme) when theme in @themes do
    theme
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(&String.capitalize/1)
  end

  def encode(%{} = custom) when is_map(custom), do: custom

  # -- Private ----------------------------------------------------------------

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp encode_base(nil), do: nil
  defp encode_base(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp encode_base(str) when is_binary(str), do: str
end
