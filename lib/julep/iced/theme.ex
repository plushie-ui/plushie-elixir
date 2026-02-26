defmodule Julep.Iced.Theme do
  @moduledoc """
  Built-in iced themes.

  Each theme is an atom that maps to the corresponding `iced::Theme` variant
  on the Rust side.
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

  @type t :: atom()

  @doc """
  Returns the list of all known built-in theme atoms.
  """
  @spec builtin_themes() :: [atom()]
  def builtin_themes, do: @themes

  @doc """
  Encodes a theme atom to its wire-format string.

  The string is the PascalCase variant name used by iced, derived from the
  atom by capitalising each segment.

  ## Examples

      iex> Julep.Iced.Theme.encode(:dark)
      "Dark"

      iex> Julep.Iced.Theme.encode(:catppuccin_mocha)
      "CatppuccinMocha"
  """
  @spec encode(t()) :: String.t()
  def encode(theme) when theme in @themes do
    theme
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(&String.capitalize/1)
  end
end
