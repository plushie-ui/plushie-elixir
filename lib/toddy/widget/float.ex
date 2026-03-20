defmodule Toddy.Widget.Float do
  @moduledoc """
  Floating overlay -- positions child with optional translation and scaling.

  ## Props

  - `translate_x` (number) -- horizontal translation in pixels. Default: 0.
  - `translate_y` (number) -- vertical translation in pixels. Default: 0.
  - `scale` (number) -- scale factor for the child content.
  - `width` (length) -- float width. See `Toddy.Type.Length`.
  - `height` (length) -- float height. See `Toddy.Type.Length`.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Type.A11y`.
  """

  alias Toddy.Type.A11y
  alias Toddy.Widget.Build

  @type option ::
          {:translate_x, number()}
          | {:translate_y, number()}
          | {:scale, number()}
          | {:width, Toddy.Type.Length.t()}
          | {:height, Toddy.Type.Length.t()}
          | {:a11y, Toddy.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          translate_x: number() | nil,
          translate_y: number() | nil,
          scale: number() | nil,
          width: Toddy.Type.Length.t() | nil,
          height: Toddy.Type.Length.t() | nil,
          a11y: Toddy.Type.A11y.t() | nil,
          children: [Toddy.Widget.ui_node() | struct()]
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

  @doc "Creates a new float struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing float struct."
  @spec with_options(float_widget :: t(), opts :: [option()]) :: t()
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
  @spec translate_x(float_widget :: t(), translate_x :: number()) :: t()
  def translate_x(%__MODULE__{} = fw, v) when is_number(v), do: %{fw | translate_x: v}

  @doc "Sets the vertical translation in pixels."
  @spec translate_y(float_widget :: t(), translate_y :: number()) :: t()
  def translate_y(%__MODULE__{} = fw, v) when is_number(v), do: %{fw | translate_y: v}

  @doc "Sets the scale factor."
  @spec scale(float_widget :: t(), scale :: number()) :: t()
  def scale(%__MODULE__{} = fw, v) when is_number(v), do: %{fw | scale: v}

  @doc "Sets the float width."
  @spec width(float_widget :: t(), width :: Toddy.Type.Length.t()) :: t()
  def width(%__MODULE__{} = fw, width), do: %{fw | width: width}

  @doc "Sets the float height."
  @spec height(float_widget :: t(), height :: Toddy.Type.Length.t()) :: t()
  def height(%__MODULE__{} = fw, height), do: %{fw | height: height}

  @doc "Appends a child to the float."
  @spec push(float_widget :: t(), child :: Toddy.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = fw, child), do: %{fw | children: [child | fw.children]}

  @doc "Appends multiple children to the float."
  @spec extend(float_widget :: t(), children :: [Toddy.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = fw, children),
    do: %{fw | children: Enum.reverse(children) ++ fw.children}

  @doc "Sets accessibility annotations."
  @spec a11y(float_widget :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = fw, a11y), do: %{fw | a11y: A11y.cast(a11y)}

  @doc "Converts this float struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(float_widget :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = fw), do: Toddy.Widget.to_node(fw)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(fw) do
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
        children: children_to_nodes(Enum.reverse(fw.children))
      }
    end
  end
end
