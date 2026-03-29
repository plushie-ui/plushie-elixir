defmodule Plushie.Widget.Svg do
  @moduledoc """
  SVG display -- renders a vector image from a file path.

  ## Props

  - `source` (string) -- path to the SVG file.
  - `width` (length) -- SVG width. Default: shrink. See `Plushie.Type.Length`.
  - `height` (length) -- SVG height. Default: shrink.
  - `content_fit` -- how the SVG fits its bounds. See `Plushie.Type.ContentFit`.
  - `rotation` (number) -- rotation angle in degrees.
  - `opacity` (number) -- opacity from 0.0 (transparent) to 1.0 (opaque).
  - `color` (color) -- color tint applied to the SVG. See `Plushie.Type.Color`.
  - `alt` (string) -- accessible label for the SVG. Auto-populates the
    accessibility label outside the `a11y` object. See "Widget-specific
    accessibility props" in `docs/accessibility.md`.
  - `description` (string) -- extended accessible description for the SVG.
    Sits outside the `a11y` object.
  - `decorative` (boolean) -- when true, hides the SVG from assistive
    technology. Sits outside the `a11y` object.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  alias Plushie.Type.Color
  alias Plushie.Widget.Build

  @type option ::
          {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:content_fit, Plushie.Type.ContentFit.t()}
          | {:rotation, number()}
          | {:opacity, number()}
          | {:color, Plushie.Type.Color.input()}
          | {:alt, String.t()}
          | {:description, String.t()}
          | {:decorative, boolean()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          source: String.t(),
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          content_fit: Plushie.Type.ContentFit.t() | nil,
          rotation: number() | nil,
          opacity: number() | nil,
          color: Plushie.Type.Color.t() | nil,
          alt: String.t() | nil,
          description: String.t() | nil,
          decorative: boolean() | nil,
          a11y: Plushie.Type.A11y.t() | nil
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
    :decorative,
    :a11y
  ]

  @valid_option_keys ~w(width height content_fit rotation opacity color alt description decorative a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{a11y: Plushie.Type.A11y}
  end

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
      {:decorative, v}, acc -> decorative(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the SVG width."
  @spec width(svg :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = svg, width), do: %{svg | width: width}

  @doc "Sets the SVG height."
  @spec height(svg :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = svg, height), do: %{svg | height: height}

  @doc "Sets how the SVG fits its bounds."
  @spec content_fit(svg :: t(), content_fit :: Plushie.Type.ContentFit.t()) :: t()
  def content_fit(%__MODULE__{} = svg, content_fit), do: %{svg | content_fit: content_fit}

  @doc "Sets the rotation angle in degrees."
  @spec rotation(svg :: t(), rotation :: number()) :: t()
  def rotation(%__MODULE__{} = svg, rotation) when is_number(rotation),
    do: %{svg | rotation: rotation}

  @doc "Sets the SVG opacity."
  @spec opacity(svg :: t(), opacity :: number()) :: t()
  def opacity(%__MODULE__{} = svg, opacity) when is_number(opacity), do: %{svg | opacity: opacity}

  @doc "Sets the color tint applied to the SVG."
  @spec color(svg :: t(), color :: Plushie.Type.Color.input()) :: t()
  def color(%__MODULE__{} = svg, color), do: %{svg | color: Color.cast(color)}

  @doc "Sets the alt text for the SVG."
  @spec alt(svg :: t(), alt :: String.t()) :: t()
  def alt(%__MODULE__{} = svg, alt) when is_binary(alt), do: %{svg | alt: alt}

  @doc "Sets a longer description for the SVG."
  @spec description(svg :: t(), description :: String.t()) :: t()
  def description(%__MODULE__{} = svg, description) when is_binary(description),
    do: %{svg | description: description}

  @doc "Sets whether the SVG is decorative (hidden from assistive technology)."
  @spec decorative(svg :: t(), decorative :: boolean()) :: t()
  def decorative(%__MODULE__{} = svg, decorative) when is_boolean(decorative),
    do: %{svg | decorative: decorative}

  @doc "Sets accessibility annotations."
  @spec a11y(svg :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = svg, a11y), do: %{svg | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this SVG struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(svg :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = svg), do: Plushie.Widget.to_node(svg)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

    def to_node(svg) do
      props =
        %{}
        |> put_if(svg.source, :source)
        |> put_if(svg.width, :width)
        |> put_if(svg.height, :height)
        |> put_if(svg.content_fit, :content_fit)
        |> put_if(svg.rotation, :rotation)
        |> put_if(svg.opacity, :opacity)
        |> put_if(svg.color, :color)
        |> put_if(svg.alt, :alt)
        |> put_if(svg.description, :description)
        |> put_if(svg.decorative, :decorative)
        |> put_if(svg.a11y, :a11y)

      %{id: svg.id, type: "svg", props: props, children: []}
    end
  end
end
