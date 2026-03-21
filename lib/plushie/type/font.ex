defmodule Plushie.Type.Font do
  @moduledoc """
  Font specification with family, weight, style, and stretch.

  Maps to iced's `Font` struct. Accepts `:default`, `:monospace`, a family
  name string, or a `%Font{}` struct with detailed font properties.
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

  @type weight :: unquote(Enum.reduce(@weights, &{:|, [], [&1, &2]}))
  @type style :: unquote(Enum.reduce(@styles, &{:|, [], [&1, &2]}))
  @type stretch :: unquote(Enum.reduce(@stretches, &{:|, [], [&1, &2]}))

  @type t ::
          :default
          | :monospace
          | String.t()
          | %__MODULE__{
              family: String.t() | nil,
              weight: weight() | nil,
              style: style() | nil,
              stretch: stretch() | nil
            }

  defstruct [:family, :weight, :style, :stretch]

  @behaviour Plushie.DSL.Buildable

  @known_keys ~w(family weight style stretch)a

  @impl Plushie.DSL.Buildable
  def __field_keys__, do: @known_keys

  @impl Plushie.DSL.Buildable
  def __field_types__, do: %{}

  @doc """
  Constructs a font from a keyword list.

  Raises `ArgumentError` if any key is not a valid font field.
  """
  @impl Plushie.DSL.Buildable
  @spec from_opts(Keyword.t()) :: %__MODULE__{}
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown font field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    %__MODULE__{
      family: Keyword.get(opts, :family),
      weight: Keyword.get(opts, :weight),
      style: Keyword.get(opts, :style),
      stretch: Keyword.get(opts, :stretch)
    }
  end

  @doc """
  Encodes a font value to the wire format.

  ## Examples

      iex> Plushie.Type.Font.encode(:default)
      "default"

      iex> Plushie.Type.Font.encode(:monospace)
      "monospace"

      iex> Plushie.Type.Font.encode("Fira Code")
      %{family: "Fira Code"}

      iex> Plushie.Type.Font.encode(%{family: "Inter", weight: :bold, style: :italic})
      %{family: "Inter", weight: "Bold", style: "Italic"}
  """
  @spec encode(font :: t()) :: String.t() | map()
  def encode(:default), do: "default"
  def encode(:monospace), do: "monospace"

  def encode(name) when is_binary(name), do: %{family: name}

  def encode(%__MODULE__{} = font) do
    font
    |> Map.from_struct()
    |> encode_map()
  end

  def encode(%{} = font) do
    encode_map(font)
  end

  defp encode_map(font) do
    result = %{}

    result =
      case Map.get(font, :family) do
        nil -> result
        family -> Map.put(result, :family, family)
      end

    result =
      case Map.get(font, :weight) do
        nil -> result
        weight when weight in @weights -> Map.put(result, :weight, encode_segment(weight))
      end

    result =
      case Map.get(font, :style) do
        nil -> result
        style when style in @styles -> Map.put(result, :style, encode_segment(style))
      end

    result =
      case Map.get(font, :stretch) do
        nil -> result
        stretch when stretch in @stretches -> Map.put(result, :stretch, encode_segment(stretch))
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

defimpl Plushie.Encode, for: Plushie.Type.Font do
  def encode(%Plushie.Type.Font{} = font) do
    Plushie.Type.Font.encode(font)
  end
end
