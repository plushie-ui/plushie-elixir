defmodule Plushie.Widget.QrCode do
  @moduledoc """
  QR Code -- renders a QR code from a data string.

  Uses the iced canvas to draw a grid of cells representing the encoded data.

  ## Props

  - `data` (string) -- the data to encode in the QR code. Required.
  - `cell_size` (number) -- size of each QR module in pixels. Default: 4.0.
  - `cell_color` (color) -- color of dark modules. Default: black.
  - `background` (color) -- color of light modules. Default: white.
  - `error_correction` (atom) -- error correction level. One of `:low`,
    `:medium` (default), `:quartile`, `:high`.
  - `alt` (string) -- accessible label for the QR code. Sits outside the
    `a11y` object. See "Widget-specific accessibility props" in
    `docs/reference/accessibility.md`.
  - `description` (string) -- extended accessible description for the QR
    code. Sits outside the `a11y` object.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  alias Plushie.Type.Color
  alias Plushie.Widget.Build

  @error_corrections [:low, :medium, :quartile, :high]

  @type error_correction ::
          unquote(Enum.reduce([:low, :medium, :quartile, :high], &{:|, [], [&1, &2]}))

  @type option ::
          {:cell_size, number()}
          | {:cell_color, Plushie.Type.Color.input()}
          | {:background, Plushie.Type.Color.input()}
          | {:error_correction, error_correction()}
          | {:alt, String.t()}
          | {:description, String.t()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          data: String.t(),
          cell_size: number() | nil,
          cell_color: Plushie.Type.Color.t() | nil,
          background: Plushie.Type.Color.t() | nil,
          error_correction: error_correction() | nil,
          alt: String.t() | nil,
          description: String.t() | nil,
          a11y: Plushie.Type.A11y.t() | nil
        }

  defstruct [
    :id,
    :data,
    :cell_size,
    :cell_color,
    :background,
    :error_correction,
    :alt,
    :description,
    :a11y
  ]

  @valid_option_keys ~w(cell_size cell_color background error_correction alt description a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new QR code struct with the given data string and optional keyword opts."
  @spec new(id :: String.t(), data :: String.t(), opts :: [option()]) :: t()
  def new(id, data, opts \\ []) when is_binary(id) and is_binary(data) do
    %__MODULE__{id: id, data: data} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing QR code struct."
  @spec with_options(qr_code :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = qr, []), do: qr

  def with_options(%__MODULE__{} = qr, opts) do
    Enum.reduce(opts, qr, fn
      {:cell_size, v}, acc -> cell_size(acc, v)
      {:cell_color, v}, acc -> cell_color(acc, v)
      {:background, v}, acc -> background(acc, v)
      {:error_correction, v}, acc -> error_correction(acc, v)
      {:alt, v}, acc -> alt(acc, v)
      {:description, v}, acc -> description(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the cell size (pixels per QR module)."
  @spec cell_size(qr_code :: t(), cell_size :: number()) :: t()
  def cell_size(%__MODULE__{} = qr, cell_size) when is_number(cell_size),
    do: %{qr | cell_size: cell_size}

  @doc "Sets the color of dark modules."
  @spec cell_color(qr_code :: t(), cell_color :: Plushie.Type.Color.input()) :: t()
  def cell_color(%__MODULE__{} = qr, cell_color), do: %{qr | cell_color: Color.cast(cell_color)}

  @doc "Sets the background color (light modules)."
  @spec background(qr_code :: t(), background :: Plushie.Type.Color.input()) :: t()
  def background(%__MODULE__{} = qr, background),
    do: %{qr | background: Color.cast(background)}

  @doc "Sets the error correction level."
  @spec error_correction(qr_code :: t(), error_correction :: error_correction()) :: t()
  def error_correction(%__MODULE__{} = qr, ec) when ec in @error_corrections,
    do: %{qr | error_correction: ec}

  @doc "Sets the accessible label for the QR code."
  @spec alt(qr_code :: t(), alt :: String.t()) :: t()
  def alt(%__MODULE__{} = qr, alt) when is_binary(alt), do: %{qr | alt: alt}

  @doc "Sets an extended accessible description for the QR code."
  @spec description(qr_code :: t(), description :: String.t()) :: t()
  def description(%__MODULE__{} = qr, description) when is_binary(description),
    do: %{qr | description: description}

  @doc "Sets accessibility annotations."
  @spec a11y(qr_code :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = qr, a11y), do: %{qr | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this QR code struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(qr_code :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = qr), do: Plushie.Widget.to_node(qr)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

    def to_node(qr) do
      props =
        %{}
        |> put_if(qr.data, :data)
        |> put_if(qr.cell_size, :cell_size)
        |> put_if(qr.cell_color, :cell_color)
        |> put_if(qr.background, :background)
        |> put_if(qr.error_correction, :error_correction)
        |> put_if(qr.alt, :alt)
        |> put_if(qr.description, :description)
        |> put_if(qr.a11y, :a11y)

      %{id: qr.id, type: "qr_code", props: props, children: []}
    end
  end
end
