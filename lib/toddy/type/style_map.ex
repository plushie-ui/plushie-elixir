defmodule Toddy.Type.StyleMap do
  @moduledoc """
  Per-instance widget styling that crosses the IPC boundary as a plain map.

  A `StyleMap` lets you override visual properties (background, text color,
  border, shadow) on individual widget instances without defining a named
  style. Status overrides (`hovered`, `pressed`, `disabled`, `focused`) apply
  partial style changes for those interaction states.

  The `background` field accepts either a solid color (hex string or named
  atom) or a `Toddy.Type.Gradient` for gradient fills.

  ## Wire format

      %{
        "background" => "#ff0000",
        "text_color" => "#ffffff",
        "border" => %{"color" => "#000000", "width" => 1, "radius" => 4},
        "hovered" => %{"background" => "#cc0000"},
        "pressed" => %{"background" => "#990000"}
      }

  ## Example

      style = Toddy.Type.StyleMap.new()
              |> Toddy.Type.StyleMap.background("#3366ff")
              |> Toddy.Type.StyleMap.text_color(:white)
              |> Toddy.Type.StyleMap.hovered(%{background: "#5588ff"})

      Button.new("btn", "Click me", style: style)

  Gradient backgrounds work the same way:

      gradient = Toddy.Type.Gradient.linear(90, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])

      style = Toddy.Type.StyleMap.new()
              |> Toddy.Type.StyleMap.background(gradient)

      Container.new("ctr", [], style: style)
  """

  alias Toddy.Type.Color
  alias Toddy.Type.Gradient

  @typedoc "Partial style override for an interaction state."
  @type status_override :: %{
          optional(:background) => Color.t() | Gradient.t(),
          optional(:text_color) => Color.t(),
          optional(:border) => Toddy.Type.Border.t(),
          optional(:shadow) => Toddy.Type.Shadow.t()
        }

  @type t :: %__MODULE__{
          base: atom() | nil,
          background: Color.t() | Gradient.t() | nil,
          text_color: Color.t() | nil,
          border: Toddy.Type.Border.t() | nil,
          shadow: Toddy.Type.Shadow.t() | nil,
          hovered: status_override() | nil,
          pressed: status_override() | nil,
          disabled: status_override() | nil,
          focused: status_override() | nil
        }

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
  def background(%__MODULE__{} = style_map, %{type: "linear"} = gradient) do
    %{style_map | background: gradient}
  end

  def background(%__MODULE__{} = style_map, background) do
    %{style_map | background: Color.cast(background)}
  end

  @doc "Sets the text color. Accepts a hex string or named color atom."
  @spec text_color(style_map :: t(), text_color :: Color.input()) :: t()
  def text_color(%__MODULE__{} = style_map, text_color) do
    %{style_map | text_color: Color.cast(text_color)}
  end

  @doc "Sets the border specification."
  @spec border(style_map :: t(), border :: Toddy.Type.Border.t()) :: t()
  def border(%__MODULE__{} = style_map, border) do
    %{style_map | border: border}
  end

  @doc "Sets the shadow specification."
  @spec shadow(style_map :: t(), shadow :: Toddy.Type.Shadow.t()) :: t()
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
      # Gradients pass through as-is (already a wire-format map).
      %{type: "linear"} = gradient -> Map.put(map, key, gradient)
      val -> Map.put(map, key, Color.cast(val))
    end
  end
end

defimpl Toddy.Encode, for: Toddy.Type.StyleMap do
  def encode(style_map) do
    %{}
    |> put_field("base", encode_base(style_map.base))
    |> put_field("background", style_map.background)
    |> put_field("text_color", style_map.text_color)
    |> put_field("border", style_map.border)
    |> put_field("shadow", style_map.shadow)
    |> put_field("hovered", encode_override(style_map.hovered))
    |> put_field("pressed", encode_override(style_map.pressed))
    |> put_field("disabled", encode_override(style_map.disabled))
    |> put_field("focused", encode_override(style_map.focused))
  end

  defp put_field(map, _key, nil), do: map
  defp put_field(map, key, value), do: Map.put(map, key, Toddy.Encode.encode(value))

  defp encode_base(nil), do: nil
  defp encode_base(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp encode_override(nil), do: nil

  defp encode_override(override) when is_map(override) do
    %{}
    |> put_field("background", Map.get(override, :background))
    |> put_field("text_color", Map.get(override, :text_color))
    |> put_field("border", Map.get(override, :border))
    |> put_field("shadow", Map.get(override, :shadow))
  end
end
