defmodule Julep.Iced.Widget.Image do
  @moduledoc """
  Image display -- renders a raster image from a file path.

  ## Props

  - `source` (string) -- path to the image file.
  - `width` (length) -- image width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- image height. Default: shrink.
  - `content_fit` (string) -- how the image fits its bounds: `"contain"`,
    `"cover"`, `"fill"`, `"none"`, `"scale_down"`.
  - `rotation` (number) -- rotation angle in degrees.
  - `opacity` (number) -- opacity from 0.0 (transparent) to 1.0 (opaque).
  - `border_radius` (number) -- corner radius in pixels.
  - `filter_method` (string) -- image filtering: `"linear"` (default) or `"nearest"`.
  - `expand` (boolean) -- expand image to fill available space.
  - `scale` (number) -- scale factor for the image.
  - `crop` (map) -- crop rectangle: `%{x, y, width, height}` (integer pixel values).
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:content_fit, Julep.Iced.ContentFit.t()}
          | {:rotation, number()}
          | {:opacity, number()}
          | {:border_radius, number()}
          | {:filter_method, Julep.Iced.FilterMethod.t()}
          | {:expand, boolean()}
          | {:scale, number()}
          | {:crop, map()}

  @type t :: %__MODULE__{
          id: String.t(),
          source: String.t(),
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          content_fit: Julep.Iced.ContentFit.t() | nil,
          rotation: number() | nil,
          opacity: number() | nil,
          border_radius: number() | nil,
          filter_method: Julep.Iced.FilterMethod.t() | nil,
          expand: boolean() | nil,
          scale: number() | nil,
          crop: map() | nil
        }

  defstruct [
    :id,
    :source,
    :width,
    :height,
    :content_fit,
    :rotation,
    :opacity,
    :border_radius,
    :filter_method,
    :expand,
    :scale,
    :crop
  ]

  @doc "Creates a new image struct with the given source path and optional keyword opts."
  @spec new(id :: String.t(), source :: String.t(), opts :: [option()]) :: t()
  def new(id, source, opts \\ []) when is_binary(id) and is_binary(source) do
    %__MODULE__{id: id, source: source} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing image struct."
  @spec with_options(image :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = img, []), do: img

  def with_options(%__MODULE__{} = img, opts) do
    Enum.reduce(opts, img, fn
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:content_fit, v}, acc -> content_fit(acc, v)
      {:rotation, v}, acc -> rotation(acc, v)
      {:opacity, v}, acc -> opacity(acc, v)
      {:border_radius, v}, acc -> border_radius(acc, v)
      {:filter_method, v}, acc -> filter_method(acc, v)
      {:expand, v}, acc -> expand(acc, v)
      {:scale, v}, acc -> scale(acc, v)
      {:crop, v}, acc -> crop(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the image width."
  @spec width(image :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = img, width), do: %{img | width: width}

  @doc "Sets the image height."
  @spec height(image :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = img, height), do: %{img | height: height}

  @doc "Sets how the image fits its bounds."
  @spec content_fit(image :: t(), content_fit :: Julep.Iced.ContentFit.t()) :: t()
  def content_fit(%__MODULE__{} = img, content_fit), do: %{img | content_fit: content_fit}

  @doc "Sets the rotation angle in degrees."
  @spec rotation(image :: t(), rotation :: number()) :: t()
  def rotation(%__MODULE__{} = img, rotation), do: %{img | rotation: rotation}

  @doc "Sets the image opacity."
  @spec opacity(image :: t(), opacity :: number()) :: t()
  def opacity(%__MODULE__{} = img, opacity), do: %{img | opacity: opacity}

  @doc "Sets the border radius."
  @spec border_radius(image :: t(), border_radius :: number()) :: t()
  def border_radius(%__MODULE__{} = img, border_radius), do: %{img | border_radius: border_radius}

  @doc "Sets the image filter method."
  @spec filter_method(image :: t(), filter_method :: Julep.Iced.FilterMethod.t()) :: t()
  def filter_method(%__MODULE__{} = img, filter_method), do: %{img | filter_method: filter_method}

  @doc "Sets whether the image expands to fill available space."
  @spec expand(image :: t(), expand :: boolean()) :: t()
  def expand(%__MODULE__{} = img, expand), do: %{img | expand: expand}

  @doc "Sets the image scale factor."
  @spec scale(image :: t(), scale :: number()) :: t()
  def scale(%__MODULE__{} = img, scale), do: %{img | scale: scale}

  @doc "Sets the crop rectangle."
  @spec crop(image :: t(), crop :: map()) :: t()
  def crop(%__MODULE__{} = img, crop), do: %{img | crop: crop}

  @doc "Converts this image struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(image :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = img), do: Julep.Iced.Widget.to_node(img)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(img) do
      props =
        %{}
        |> put_if(img.source, "source")
        |> put_if(img.width, "width")
        |> put_if(img.height, "height")
        |> put_if(img.content_fit, "content_fit")
        |> put_if(img.rotation, "rotation")
        |> put_if(img.opacity, "opacity")
        |> put_if(img.border_radius, "border_radius")
        |> put_if(img.filter_method, "filter_method")
        |> put_if(img.expand, "expand")
        |> put_if(img.scale, "scale")
        |> put_if(img.crop, "crop")

      %{id: img.id, type: "image", props: props, children: []}
    end
  end
end
