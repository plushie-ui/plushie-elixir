defmodule Toddy.Widget.QrCode do
  @moduledoc """
  QR Code -- renders a QR code from a data string.

  Uses the iced canvas to draw a grid of cells representing the encoded data.

  ## Props

  - `data` (string) -- the data to encode in the QR code. Required.
  - `cell_size` (number) -- size of each QR module in pixels. Default: 4.0.
  - `cell_color` (color) -- color of dark modules. Default: black.
  - `background_color` (color) -- color of light modules. Default: white.
  - `error_correction` (atom) -- error correction level. One of `:low`,
    `:medium` (default), `:quartile`, `:high`.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Type.A11y`.
  """

  alias Toddy.Type.A11y
  alias Toddy.Type.Color
  alias Toddy.Widget.Build

  @error_corrections [:low, :medium, :quartile, :high]

  @type error_correction ::
          unquote(Enum.reduce([:low, :medium, :quartile, :high], &{:|, [], [&1, &2]}))

  @type option ::
          {:cell_size, number()}
          | {:cell_color, Toddy.Type.Color.input()}
          | {:background_color, Toddy.Type.Color.input()}
          | {:error_correction, error_correction()}
          | {:a11y, Toddy.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          data: String.t(),
          cell_size: number() | nil,
          cell_color: Toddy.Type.Color.t() | nil,
          background_color: Toddy.Type.Color.t() | nil,
          error_correction: error_correction() | nil,
          a11y: Toddy.Type.A11y.t() | nil
        }

  defstruct [:id, :data, :cell_size, :cell_color, :background_color, :error_correction, :a11y]

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
      {:background_color, v}, acc -> background_color(acc, v)
      {:error_correction, v}, acc -> error_correction(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the cell size (pixels per QR module)."
  @spec cell_size(qr_code :: t(), cell_size :: number()) :: t()
  def cell_size(%__MODULE__{} = qr, cell_size) when is_number(cell_size),
    do: %{qr | cell_size: cell_size}

  @doc "Sets the color of dark modules."
  @spec cell_color(qr_code :: t(), cell_color :: Toddy.Type.Color.input()) :: t()
  def cell_color(%__MODULE__{} = qr, cell_color), do: %{qr | cell_color: Color.cast(cell_color)}

  @doc "Sets the background color (light modules)."
  @spec background_color(qr_code :: t(), background_color :: Toddy.Type.Color.input()) :: t()
  def background_color(%__MODULE__{} = qr, background_color),
    do: %{qr | background_color: Color.cast(background_color)}

  @doc "Sets the error correction level."
  @spec error_correction(qr_code :: t(), error_correction :: error_correction()) :: t()
  def error_correction(%__MODULE__{} = qr, ec) when ec in @error_corrections,
    do: %{qr | error_correction: ec}

  @doc "Sets accessibility annotations."
  @spec a11y(qr_code :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = qr, a11y), do: %{qr | a11y: A11y.cast(a11y)}

  @doc "Converts this QR code struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(qr_code :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = qr), do: Toddy.Widget.to_node(qr)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(qr) do
      props =
        %{}
        |> put_if(qr.data, "data")
        |> put_if(qr.cell_size, "cell_size")
        |> put_if(qr.cell_color, "cell_color")
        |> put_if(qr.background_color, "background_color")
        |> put_if(qr.error_correction, "error_correction")
        |> put_if(qr.a11y, "a11y")

      %{id: qr.id, type: "qr_code", props: props, children: []}
    end
  end
end
