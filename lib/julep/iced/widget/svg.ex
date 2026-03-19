defmodule Julep.Iced.Widget.Svg do
  @moduledoc """
  SVG display -- renders a vector image from a file path.

  ## Props

  - `source` (string) -- path to the SVG file.
  - `width` (length) -- SVG width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- SVG height. Default: shrink.
  - `content_fit` -- how the SVG fits its bounds. See `Julep.Iced.ContentFit`.
  - `rotation` (number) -- rotation angle in degrees.
  - `opacity` (number) -- opacity from 0.0 (transparent) to 1.0 (opaque).
  - `color` (color) -- color tint applied to the SVG. See `Julep.Iced.Color`.
  - `alt` (string) -- alt text for the SVG (accessibility).
  - `description` (string) -- longer description for the SVG (accessibility).
  - `a11y` (map) -- accessibility overrides. See `Julep.Iced.A11y`.
  """

  alias Julep.Iced.A11y
  alias Julep.Iced.Color
  alias Julep.Iced.Widget.Build

  @type option ::
          {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:content_fit, Julep.Iced.ContentFit.t()}
          | {:rotation, number()}
          | {:opacity, number()}
          | {:color, Julep.Iced.Color.input()}
          | {:alt, String.t()}
          | {:description, String.t()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          source: String.t(),
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          content_fit: Julep.Iced.ContentFit.t() | nil,
          rotation: number() | nil,
          opacity: number() | nil,
          color: Julep.Iced.Color.t() | nil,
          alt: String.t() | nil,
          description: String.t() | nil,
          a11y: Julep.Iced.A11y.t() | nil
        }

  defstruct [
    :id,
    :source,
    :width,
    :height,
    :content_fit,
    :rotation,
    :opacity,
    :color,
    :alt,
    :description,
    :a11y
  ]

  @doc "Creates a new SVG struct with the given source path and optional keyword opts."
  @spec new(id :: String.t(), source :: String.t(), opts :: [option()]) :: t()
  def new(id, source, opts \\ []) when is_binary(id) and is_binary(source) do
    %__MODULE__{id: id, source: source} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing SVG struct."
  @spec with_options(svg :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = svg, []), do: svg

  def with_options(%__MODULE__{} = svg, opts) do
    Enum.reduce(opts, svg, fn
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:content_fit, v}, acc -> content_fit(acc, v)
      {:rotation, v}, acc -> rotation(acc, v)
      {:opacity, v}, acc -> opacity(acc, v)
      {:color, v}, acc -> color(acc, v)
      {:alt, v}, acc -> alt(acc, v)
      {:description, v}, acc -> description(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the SVG width."
  @spec width(svg :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = svg, width), do: %{svg | width: width}

  @doc "Sets the SVG height."
  @spec height(svg :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = svg, height), do: %{svg | height: height}

  @doc "Sets how the SVG fits its bounds."
  @spec content_fit(svg :: t(), content_fit :: Julep.Iced.ContentFit.t()) :: t()
  def content_fit(%__MODULE__{} = svg, content_fit), do: %{svg | content_fit: content_fit}

  @doc "Sets the rotation angle in degrees."
  @spec rotation(svg :: t(), rotation :: number()) :: t()
  def rotation(%__MODULE__{} = svg, rotation) when is_number(rotation), do: %{svg | rotation: rotation}

  @doc "Sets the SVG opacity."
  @spec opacity(svg :: t(), opacity :: number()) :: t()
  def opacity(%__MODULE__{} = svg, opacity) when is_number(opacity), do: %{svg | opacity: opacity}

  @doc "Sets the color tint applied to the SVG."
  @spec color(svg :: t(), color :: Julep.Iced.Color.input()) :: t()
  def color(%__MODULE__{} = svg, color), do: %{svg | color: Color.cast(color)}

  @doc "Sets the alt text for the SVG."
  @spec alt(svg :: t(), alt :: String.t()) :: t()
  def alt(%__MODULE__{} = svg, alt) when is_binary(alt), do: %{svg | alt: alt}

  @doc "Sets a longer description for the SVG."
  @spec description(svg :: t(), description :: String.t()) :: t()
  def description(%__MODULE__{} = svg, description) when is_binary(description),
    do: %{svg | description: description}

  @doc "Sets accessibility annotations."
  @spec a11y(svg :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = svg, a11y), do: %{svg | a11y: A11y.cast(a11y)}

  @doc "Converts this SVG struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(svg :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = svg), do: Julep.Iced.Widget.to_node(svg)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(svg) do
      props =
        %{}
        |> put_if(svg.source, "source")
        |> put_if(svg.width, "width")
        |> put_if(svg.height, "height")
        |> put_if(svg.content_fit, "content_fit")
        |> put_if(svg.rotation, "rotation")
        |> put_if(svg.opacity, "opacity")
        |> put_if(svg.color, "color")
        |> put_if(svg.alt, "alt")
        |> put_if(svg.description, "description")
        |> put_if(svg.a11y, "a11y")

      %{id: svg.id, type: "svg", props: props, children: []}
    end
  end
end
