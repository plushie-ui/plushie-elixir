defmodule Plushie.Widget.Pin do
  @moduledoc """
  Pin layout -- positions child at absolute coordinates.

  ## Props

  - `x` (number) -- x position in pixels. Default: 0.
  - `y` (number) -- y position in pixels. Default: 0.
  - `width` (length) -- pin container width. Default: shrink. See `Plushie.Type.Length`.
  - `height` (length) -- pin container height. Default: shrink.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  alias Plushie.Widget.Build

  @type option ::
          {:x, number()}
          | {:y, number()}
          | {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          x: number() | nil,
          y: number() | nil,
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          a11y: Plushie.Type.A11y.t() | nil,
          children: [Plushie.Widget.ui_node() | struct()]
        }

  defstruct [
    :id,
    :x,
    :y,
    :width,
    :height,
    :a11y,
    children: []
  ]

  @valid_option_keys ~w(x y width height a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new pin struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing pin struct."
  @spec with_options(pin :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = pin, []), do: pin

  def with_options(%__MODULE__{} = pin, opts) do
    Enum.reduce(opts, pin, fn
      {:x, v}, acc -> x(acc, v)
      {:y, v}, acc -> y(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the x position in pixels."
  @spec x(pin :: t(), x :: number()) :: t()
  def x(%__MODULE__{} = pin, x) when is_number(x), do: %{pin | x: x}

  @doc "Sets the y position in pixels."
  @spec y(pin :: t(), y :: number()) :: t()
  def y(%__MODULE__{} = pin, y) when is_number(y), do: %{pin | y: y}

  @doc "Sets the pin container width."
  @spec width(pin :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = pin, width), do: %{pin | width: width}

  @doc "Sets the pin container height."
  @spec height(pin :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = pin, height), do: %{pin | height: height}

  @doc "Appends a child to the pin."
  @spec push(pin :: t(), child :: Plushie.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = pin, child), do: %{pin | children: [child | pin.children]}

  @doc "Appends multiple children to the pin."
  @spec extend(pin :: t(), children :: [Plushie.Widget.ui_node() | struct()]) ::
          t()
  def extend(%__MODULE__{} = pin, children),
    do: %{pin | children: Enum.reverse(children) ++ pin.children}

  @doc "Sets accessibility annotations."
  @spec a11y(pin :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = pin, a11y), do: %{pin | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this pin struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(pin :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = pin), do: Plushie.Widget.to_node(pin)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

    def to_node(pin) do
      props =
        %{}
        |> put_if(pin.x, :x)
        |> put_if(pin.y, :y)
        |> put_if(pin.width, :width)
        |> put_if(pin.height, :height)
        |> put_if(pin.a11y, :a11y)

      %{
        id: pin.id,
        type: "pin",
        props: props,
        children: children_to_nodes(Enum.reverse(pin.children))
      }
    end
  end
end
