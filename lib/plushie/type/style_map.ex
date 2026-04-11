defmodule Plushie.Type.StyleMap do
  @moduledoc """
  Per-instance widget styling that crosses the IPC boundary as a plain map.

  A `StyleMap` lets you override visual properties (background, text color,
  border, shadow) on individual widget instances without defining a named
  style. Status overrides (`hovered`, `pressed`, `disabled`, `focused`) apply
  partial style changes for those interaction states.

  The `background` field accepts either a solid color (hex string or named
  atom) or a `Plushie.Type.Gradient` for gradient fills.

  ## Wire format

      %{
        background: "#ff0000",
        text_color: "#ffffff",
        border: %{color: "#000000", width: 1, radius: 4},
        hovered: %{background: "#cc0000"},
        pressed: %{background: "#990000"}
      }

  ## Example

      style = Plushie.Type.StyleMap.new()
              |> Plushie.Type.StyleMap.background("#3366ff")
              |> Plushie.Type.StyleMap.text_color(:white)
              |> Plushie.Type.StyleMap.hovered(%{background: "#5588ff"})

      Button.new("btn", "Click me", style: style)

  Gradient backgrounds work the same way:

      gradient = Plushie.Type.Gradient.linear_from_angle(90, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])

      style = Plushie.Type.StyleMap.new()
              |> Plushie.Type.StyleMap.background(gradient)

      Container.new("ctr", [], style: style)
  """

  alias Plushie.Type.Color
  alias Plushie.Type.Gradient

  @typedoc "Partial style override for an interaction state."
  @type status_override :: %{
          optional(:background) => Color.t() | Gradient.t(),
          optional(:text_color) => Color.t(),
          optional(:border) => Plushie.Type.Border.t(),
          optional(:shadow) => Plushie.Type.Shadow.t()
        }

  @type t :: %__MODULE__{
          base: atom() | nil,
          background: Color.t() | Gradient.t() | nil,
          text_color: Color.t() | nil,
          border: Plushie.Type.Border.t() | nil,
          shadow: Plushie.Type.Shadow.t() | nil,
          hovered: status_override() | nil,
          pressed: status_override() | nil,
          disabled: status_override() | nil,
          focused: status_override() | nil
        }

  @known_keys ~w(base background text_color border shadow hovered pressed disabled focused)a

  defstruct [
    :base,
    :background,
    :text_color,
    :border,
    :shadow,
    :hovered,
    :pressed,
    :disabled,
    :focused
  ]

  @doc "Validates and returns a StyleMap struct."
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(%__MODULE__{} = v), do: {:ok, v}
  def cast(_), do: :error

  @doc "Creates an empty style map."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Sets the base preset to extend from instead of starting from the widget default."
  @spec base(style_map :: t(), preset :: atom()) :: t()
  def base(%__MODULE__{} = style_map, preset) when is_atom(preset) do
    %{style_map | base: preset}
  end

  @doc "Sets the background. Accepts a color (any form `Color.cast/1` supports) or a `Gradient`."
  @spec background(style_map :: t(), background :: Color.input() | Gradient.t()) :: t()
  def background(%__MODULE__{} = style_map, %Gradient{} = gradient) do
    %{style_map | background: gradient}
  end

  def background(%__MODULE__{} = style_map, background) do
    %{style_map | background: elem(Color.cast(background), 1)}
  end

  @doc "Sets the text color. Accepts a hex string or named color atom."
  @spec text_color(style_map :: t(), text_color :: Color.input()) :: t()
  def text_color(%__MODULE__{} = style_map, text_color) do
    %{style_map | text_color: elem(Color.cast(text_color), 1)}
  end

  @doc "Sets the border specification."
  @spec border(style_map :: t(), border :: Plushie.Type.Border.t()) :: t()
  def border(%__MODULE__{} = style_map, border) do
    %{style_map | border: border}
  end

  @doc "Sets the shadow specification."
  @spec shadow(style_map :: t(), shadow :: Plushie.Type.Shadow.t()) :: t()
  def shadow(%__MODULE__{} = style_map, shadow) do
    %{style_map | shadow: shadow}
  end

  @doc "Sets the hovered status override. Accepts a map or keyword list."
  @spec hovered(style_map :: t(), hovered :: status_override() | keyword()) :: t()
  def hovered(%__MODULE__{} = style_map, hovered) do
    %{style_map | hovered: normalize_override(hovered)}
  end

  @doc "Sets the pressed status override. Accepts a map or keyword list."
  @spec pressed(style_map :: t(), pressed :: status_override() | keyword()) :: t()
  def pressed(%__MODULE__{} = style_map, pressed) do
    %{style_map | pressed: normalize_override(pressed)}
  end

  @doc "Sets the disabled status override. Accepts a map or keyword list."
  @spec disabled(style_map :: t(), disabled :: status_override() | keyword()) :: t()
  def disabled(%__MODULE__{} = style_map, disabled) do
    %{style_map | disabled: normalize_override(disabled)}
  end

  @doc "Sets the focused status override. Accepts a map or keyword list."
  @spec focused(style_map :: t(), focused :: status_override() | keyword()) :: t()
  def focused(%__MODULE__{} = style_map, focused) do
    %{style_map | focused: normalize_override(focused)}
  end

  def __field_keys__, do: @known_keys

  def __field_types__ do
    %{
      border: Plushie.Type.Border,
      shadow: Plushie.Type.Shadow
    }
  end

  @doc "Constructs a `StyleMap` from a keyword list."
  @spec from_opts(opts :: keyword()) :: t()
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown style field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    Enum.reduce(opts, new(), fn
      {:base, v}, acc -> base(acc, v)
      {:background, v}, acc -> background(acc, v)
      {:text_color, v}, acc -> text_color(acc, v)
      {:border, v}, acc -> border(acc, v)
      {:shadow, v}, acc -> shadow(acc, v)
      {:hovered, v}, acc -> hovered(acc, v)
      {:pressed, v}, acc -> pressed(acc, v)
      {:disabled, v}, acc -> disabled(acc, v)
      {:focused, v}, acc -> focused(acc, v)
    end)
  end

  @spec normalize_override(override :: status_override() | keyword()) :: status_override()
  defp normalize_override(override) when is_list(override),
    do: normalize_override(Map.new(override))

  defp normalize_override(override) when is_map(override) do
    override
    |> cast_color_field(:background)
    |> cast_color_field(:text_color)
  end

  defp cast_color_field(map, key) do
    case Map.get(map, key) do
      nil -> map
      %Gradient{} = gradient -> Map.put(map, key, gradient)
      val -> Map.put(map, key, elem(Color.cast(val), 1))
    end
  end

  @doc false
  @spec encode(t()) :: map()
  def encode(%__MODULE__{} = style_map) do
    %{}
    |> encode_put(:base, encode_base(style_map.base))
    |> encode_put(:background, style_map.background)
    |> encode_put(:text_color, style_map.text_color)
    |> encode_put_nested(:border, style_map.border)
    |> encode_put_nested(:shadow, style_map.shadow)
    |> encode_put(:hovered, encode_override(style_map.hovered))
    |> encode_put(:pressed, encode_override(style_map.pressed))
    |> encode_put(:disabled, encode_override(style_map.disabled))
    |> encode_put(:focused, encode_override(style_map.focused))
  end

  defp encode_put(map, _key, nil), do: map
  defp encode_put(map, key, value), do: Map.put(map, key, value)

  defp encode_put_nested(map, _key, nil), do: map

  defp encode_put_nested(map, key, %mod{} = value) do
    if function_exported?(mod, :encode, 1) do
      Map.put(map, key, mod.encode(value))
    else
      Map.put(map, key, value)
    end
  end

  defp encode_put_nested(map, key, value), do: Map.put(map, key, value)

  defp encode_base(nil), do: nil
  defp encode_base(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp encode_override(nil), do: nil

  defp encode_override(override) when is_map(override) do
    %{}
    |> encode_put(:background, Map.get(override, :background))
    |> encode_put(:text_color, Map.get(override, :text_color))
    |> encode_put_nested(:border, Map.get(override, :border))
    |> encode_put_nested(:shadow, Map.get(override, :shadow))
  end
end
