defmodule Julep.Iced.Font do
  @moduledoc """
  Font values matching iced's `Font` type.

  Supported forms:

  - `:default` -- the platform default font
  - `:monospace` -- the platform monospace font
  - `"FontName"` -- a named font family
  - `%{family: family, weight: weight, style: style}` -- full descriptor
    where weight is one of `:thin`, `:extra_light`, `:light`, `:normal`,
    `:medium`, `:semi_bold`, `:bold`, `:extra_bold`, `:black` and style
    is one of `:normal`, `:italic`, `:oblique`.
  """

  @weights [:thin, :extra_light, :light, :normal, :medium, :semi_bold, :bold, :extra_bold, :black]
  @styles [:normal, :italic, :oblique]
  @stretches [
    :ultra_condensed,
    :extra_condensed,
    :condensed,
    :semi_condensed,
    :normal,
    :semi_expanded,
    :expanded,
    :extra_expanded,
    :ultra_expanded
  ]

  @type t :: :default | :monospace | String.t() | map()

  @doc """
  Encodes a font value to the wire format.

  ## Examples

      iex> Julep.Iced.Font.encode(:default)
      "default"

      iex> Julep.Iced.Font.encode(:monospace)
      "monospace"

      iex> Julep.Iced.Font.encode("Fira Code")
      %{"family" => "Fira Code"}

      iex> Julep.Iced.Font.encode(%{family: "Inter", weight: :bold, style: :italic})
      %{"family" => "Inter", "weight" => "Bold", "style" => "Italic"}
  """
  @spec encode(t()) :: String.t() | map()
  def encode(:default), do: "default"
  def encode(:monospace), do: "monospace"

  def encode(name) when is_binary(name), do: %{"family" => name}

  def encode(%{} = font) do
    result = %{}

    result =
      case Map.get(font, :family) do
        nil -> result
        family -> Map.put(result, "family", family)
      end

    result =
      case Map.get(font, :weight) do
        nil -> result
        weight when weight in @weights -> Map.put(result, "weight", encode_segment(weight))
      end

    result =
      case Map.get(font, :style) do
        nil -> result
        style when style in @styles -> Map.put(result, "style", encode_segment(style))
      end

    result =
      case Map.get(font, :stretch) do
        nil -> result
        stretch when stretch in @stretches -> Map.put(result, "stretch", encode_segment(stretch))
      end

    result
  end

  defp encode_segment(atom) do
    atom
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(&String.capitalize/1)
  end
end
