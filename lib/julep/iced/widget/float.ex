defmodule Julep.Iced.Widget.Float do
  @moduledoc """
  Floating overlay -- positions child with optional translation and scaling.

  ## Props

  - `translate_x` (number) -- horizontal translation in pixels. Default: 0.
  - `translate_y` (number) -- vertical translation in pixels. Default: 0.
  - `scale` (number) -- scale factor for the child content.
  """

  alias Julep.Iced.A11y
  alias Julep.Iced.Widget.Build

  @type option ::
          {:translate_x, number()}
          | {:translate_y, number()}
          | {:scale, number()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          translate_x: number() | nil,
          translate_y: number() | nil,
          scale: number() | nil,
          a11y: Julep.Iced.A11y.t() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :translate_x,
    :translate_y,
    :scale,
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
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the horizontal translation in pixels."
  @spec translate_x(float_widget :: t(), translate_x :: number()) :: t()
  def translate_x(%__MODULE__{} = fw, translate_x), do: %{fw | translate_x: translate_x}

  @doc "Sets the vertical translation in pixels."
  @spec translate_y(float_widget :: t(), translate_y :: number()) :: t()
  def translate_y(%__MODULE__{} = fw, translate_y), do: %{fw | translate_y: translate_y}

  @doc "Sets the scale factor."
  @spec scale(float_widget :: t(), scale :: number()) :: t()
  def scale(%__MODULE__{} = fw, scale), do: %{fw | scale: scale}

  @doc "Appends a child to the float."
  @spec push(float_widget :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = fw, child), do: %{fw | children: [child | fw.children]}

  @doc "Appends multiple children to the float."
  @spec extend(float_widget :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = fw, children),
    do: %{fw | children: Enum.reverse(children) ++ fw.children}

  @doc "Sets accessibility annotations."
  @spec a11y(float_widget :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = fw, a11y), do: %{fw | a11y: A11y.cast(a11y)}

  @doc "Converts this float struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(float_widget :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = fw), do: Julep.Iced.Widget.to_node(fw)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(fw) do
      props =
        %{}
        |> put_if(fw.translate_x, "translate_x")
        |> put_if(fw.translate_y, "translate_y")
        |> put_if(fw.scale, "scale")
        |> put_if(fw.a11y, "a11y")

      %{
        id: fw.id,
        type: "float",
        props: props,
        children: children_to_nodes(Enum.reverse(fw.children))
      }
    end
  end
end
