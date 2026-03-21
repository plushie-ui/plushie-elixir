defmodule Plushie.Widget.Image do
  @moduledoc """
  Image display -- renders a raster image from a file path or an in-memory handle.

  ## Props

  - `source` (string or handle ref) -- path to the image file, or
    `%{handle: name}` for an in-memory image created via `Plushie.Command.create_image/2`.
  - `width` (length) -- image width. Default: shrink. See `Plushie.Type.Length`.
  - `height` (length) -- image height. Default: shrink.
  - `content_fit` -- how the image fits its bounds. See `Plushie.Type.ContentFit`.
  - `rotation` (number) -- rotation angle in degrees.
  - `opacity` (number) -- opacity from 0.0 (transparent) to 1.0 (opaque).
  - `border_radius` (number) -- corner radius in pixels.
  - `filter_method` -- image interpolation mode. See `Plushie.Type.FilterMethod`.
  - `expand` (boolean) -- expand image to fill available space.
  - `scale` (number) -- scale factor for the image.
  - `crop` (map) -- crop rectangle: `%{x, y, width, height}` (integer pixel values).
  - `alt` (string) -- accessible label for the image. Auto-populates the
    accessibility label outside the `a11y` object. See "Widget-specific
    accessibility props" in `docs/accessibility.md`.
  - `description` (string) -- extended accessible description for the image.
    Sits outside the `a11y` object.
  - `decorative` (boolean) -- when true, hides the image from assistive
    technology. Sits outside the `a11y` object.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  alias Plushie.Type.A11y
  alias Plushie.Widget.Build

  @typedoc "Image source: a file path string or a handle reference map."
  @type source :: String.t() | %{handle: String.t()}

  @type option ::
          {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:content_fit, Plushie.Type.ContentFit.t()}
          | {:rotation, number()}
          | {:opacity, number()}
          | {:border_radius, number()}
          | {:filter_method, Plushie.Type.FilterMethod.t()}
          | {:expand, boolean()}
          | {:scale, number()}
          | {:crop, map()}
          | {:alt, String.t()}
          | {:description, String.t()}
          | {:decorative, boolean()}
          | {:a11y, Plushie.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          source: source(),
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          content_fit: Plushie.Type.ContentFit.t() | nil,
          rotation: number() | nil,
          opacity: number() | nil,
          border_radius: number() | nil,
          filter_method: Plushie.Type.FilterMethod.t() | nil,
          expand: boolean() | nil,
          scale: number() | nil,
          crop: map() | nil,
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
    :border_radius,
    :filter_method,
    :expand,
    :scale,
    :crop,
    :alt,
    :description,
    :decorative,
    :a11y
  ]

  @valid_option_keys ~w(width height content_fit rotation opacity border_radius filter_method expand scale crop alt description decorative a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{a11y: Plushie.Type.A11y}
  end

  @doc """
  Creates a new image struct with the given source and optional keyword opts.

  The `source` can be a file path string or a handle reference map
  (`%{handle: "name"}`) for in-memory images created via
  `Plushie.Command.create_image/2`.
  """
  @spec new(id :: String.t(), source :: source(), opts :: [option()]) :: t()
  def new(id, source, opts \\ [])

  def new(id, source, opts) when is_binary(id) and is_binary(source) do
    %__MODULE__{id: id, source: source} |> with_options(opts)
  end

  def new(id, %{handle: handle} = source, opts) when is_binary(id) and is_binary(handle) do
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
      {:alt, v}, acc -> alt(acc, v)
      {:description, v}, acc -> description(acc, v)
      {:decorative, v}, acc -> decorative(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the image width."
  @spec width(image :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = img, width), do: %{img | width: width}

  @doc "Sets the image height."
  @spec height(image :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = img, height), do: %{img | height: height}

  @doc "Sets how the image fits its bounds."
  @spec content_fit(image :: t(), content_fit :: Plushie.Type.ContentFit.t()) :: t()
  def content_fit(%__MODULE__{} = img, content_fit), do: %{img | content_fit: content_fit}

  @doc "Sets the rotation angle in degrees."
  @spec rotation(image :: t(), rotation :: number()) :: t()
  def rotation(%__MODULE__{} = img, rotation) when is_number(rotation),
    do: %{img | rotation: rotation}

  @doc "Sets the image opacity (0.0 to 1.0)."
  @spec opacity(image :: t(), opacity :: number()) :: t()
  def opacity(%__MODULE__{} = img, opacity) when is_number(opacity),
    do: %{img | opacity: opacity}

  @doc "Sets the border radius in pixels."
  @spec border_radius(image :: t(), border_radius :: number()) :: t()
  def border_radius(%__MODULE__{} = img, border_radius) when is_number(border_radius),
    do: %{img | border_radius: border_radius}

  @doc "Sets the image filter method."
  @spec filter_method(image :: t(), filter_method :: Plushie.Type.FilterMethod.t()) :: t()
  def filter_method(%__MODULE__{} = img, filter_method), do: %{img | filter_method: filter_method}

  @doc "Sets whether the image expands to fill available space."
  @spec expand(image :: t(), expand :: boolean()) :: t()
  def expand(%__MODULE__{} = img, expand) when is_boolean(expand), do: %{img | expand: expand}

  @doc "Sets the image scale factor."
  @spec scale(image :: t(), scale :: number()) :: t()
  def scale(%__MODULE__{} = img, scale) when is_number(scale), do: %{img | scale: scale}

  @doc "Sets the crop rectangle."
  @spec crop(image :: t(), crop :: map()) :: t()
  def crop(%__MODULE__{} = img, crop), do: %{img | crop: crop}

  @doc "Sets the alt text for the image."
  @spec alt(image :: t(), alt :: String.t()) :: t()
  def alt(%__MODULE__{} = img, alt) when is_binary(alt), do: %{img | alt: alt}

  @doc "Sets a longer description for the image."
  @spec description(image :: t(), description :: String.t()) :: t()
  def description(%__MODULE__{} = img, description) when is_binary(description),
    do: %{img | description: description}

  @doc "Sets whether the image is decorative (hidden from assistive technology)."
  @spec decorative(image :: t(), decorative :: boolean()) :: t()
  def decorative(%__MODULE__{} = img, decorative) when is_boolean(decorative),
    do: %{img | decorative: decorative}

  @doc "Sets accessibility annotations."
  @spec a11y(image :: t(), a11y :: Plushie.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = img, a11y), do: %{img | a11y: A11y.cast(a11y)}

  @doc "Converts this image struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(image :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = img), do: Plushie.Widget.to_node(img)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

    def to_node(img) do
      props =
        %{}
        |> put_if(img.source, :source)
        |> put_if(img.width, :width)
        |> put_if(img.height, :height)
        |> put_if(img.content_fit, :content_fit)
        |> put_if(img.rotation, :rotation)
        |> put_if(img.opacity, :opacity)
        |> put_if(img.border_radius, :border_radius)
        |> put_if(img.filter_method, :filter_method)
        |> put_if(img.expand, :expand)
        |> put_if(img.scale, :scale)
        |> put_if(img.crop, :crop)
        |> put_if(img.alt, :alt)
        |> put_if(img.description, :description)
        |> put_if(img.decorative, :decorative)
        |> put_if(img.a11y, :a11y)

      %{id: img.id, type: "image", props: props, children: []}
    end
  end
end
