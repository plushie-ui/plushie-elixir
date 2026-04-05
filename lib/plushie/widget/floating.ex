defmodule Plushie.Widget.Floating do
  @moduledoc """
  Floating overlay -- positions child with optional translation and scaling.

  ## Props

  - `translate_x` (number) -- horizontal translation in pixels. Default: 0.
  - `translate_y` (number) -- vertical translation in pixels. Default: 0.
  - `scale` (number) -- scale factor for the child content.
  - `width` (length) -- float width. See `Plushie.Type.Length`.
  - `height` (length) -- float height. See `Plushie.Type.Length`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  alias Plushie.Widget.Build

  @type option ::
          {:translate_x, number()}
          | {:translate_y, number()}
          | {:scale, number()}
          | {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          translate_x: number() | nil,
          translate_y: number() | nil,
          scale: number() | nil,
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          a11y: Plushie.Type.A11y.t() | nil,
          children: [Plushie.Widget.child()]
        }

  defstruct [
    :id,
    :translate_x,
    :translate_y,
    :scale,
    :width,
    :height,
    :a11y,
    children: []
  ]

  @valid_option_keys ~w(translate_x translate_y scale width height a11y)a

  @doc false
  def __field_keys__, do: @valid_option_keys

  @doc false
  def __field_types__ do
    %{a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new float struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing float struct."
  @spec with_options(floating :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = fw, []), do: fw

  def with_options(%__MODULE__{} = fw, opts) do
    Enum.reduce(opts, fw, fn
      {:translate_x, v}, acc -> translate_x(acc, v)
      {:translate_y, v}, acc -> translate_y(acc, v)
      {:scale, v}, acc -> scale(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the horizontal translation in pixels."
  @spec translate_x(floating :: t(), translate_x :: number()) :: t()
  def translate_x(%__MODULE__{} = fw, v) when is_number(v), do: %{fw | translate_x: v}

  @doc "Sets the vertical translation in pixels."
  @spec translate_y(floating :: t(), translate_y :: number()) :: t()
  def translate_y(%__MODULE__{} = fw, v) when is_number(v), do: %{fw | translate_y: v}

  @doc "Sets the scale factor."
  @spec scale(floating :: t(), scale :: number()) :: t()
  def scale(%__MODULE__{} = fw, v) when is_number(v), do: %{fw | scale: v}

  @doc "Sets the float width."
  @spec width(floating :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = fw, width), do: %{fw | width: width}

  @doc "Sets the float height."
  @spec height(floating :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = fw, height), do: %{fw | height: height}

  @doc "Appends a child to the float."
  @spec push(floating :: t(), child :: Plushie.Widget.child()) :: t()
  def push(%__MODULE__{} = fw, child), do: %{fw | children: [child | fw.children]}

  @doc "Appends multiple children to the float."
  @spec extend(floating :: t(), children :: [Plushie.Widget.child()]) ::
          t()
  def extend(%__MODULE__{} = fw, children),
    do: %{fw | children: Enum.reverse(children) ++ fw.children}

  @doc "Sets accessibility annotations."
  @spec a11y(floating :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = fw, a11y), do: %{fw | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this float struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(floating :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = fw), do: Plushie.Widget.to_node(fw)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

    def to_node(fw) do
      children = Enum.reverse(fw.children)
      validate_single_child!(fw.id, "floating", children)

      props =
        %{}
        |> put_if(fw.translate_x, :translate_x)
        |> put_if(fw.translate_y, :translate_y)
        |> put_if(fw.scale, :scale)
        |> put_if(fw.width, :width)
        |> put_if(fw.height, :height)
        |> put_if(fw.a11y, :a11y)

      %{
        id: fw.id,
        type: "float",
        props: props,
        children: children_to_nodes(children)
      }
    end
  end
end
