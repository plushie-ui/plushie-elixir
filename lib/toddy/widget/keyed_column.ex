defmodule Toddy.Widget.KeyedColumn do
  @moduledoc """
  Keyed column layout -- arranges children vertically with stable identity keys.

  Like `Column`, but uses each child's `id` as a key for iced's internal
  widget diffing. This avoids unnecessary rebuilds when items are added,
  removed, or reordered in dynamic lists.

  ## Props

  - `spacing` (number) -- vertical space between children in pixels. Default: 0.
  - `padding` (number | map) -- padding inside the column. See `Toddy.Type.Padding`.
  - `width` (length) -- column width. Default: shrink. See `Toddy.Type.Length`.
  - `height` (length) -- column height. Default: shrink.
  - `max_width` (number) -- maximum width in pixels.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Type.A11y`.
  """

  alias Toddy.Type.A11y
  alias Toddy.Widget.Build

  @type option ::
          {:spacing, number()}
          | {:padding, Toddy.Type.Padding.t()}
          | {:width, Toddy.Type.Length.t()}
          | {:height, Toddy.Type.Length.t()}
          | {:max_width, number()}
          | {:a11y, Toddy.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          spacing: number() | nil,
          padding: Toddy.Type.Padding.t() | nil,
          width: Toddy.Type.Length.t() | nil,
          height: Toddy.Type.Length.t() | nil,
          max_width: number() | nil,
          a11y: Toddy.Type.A11y.t() | nil,
          children: [Toddy.Widget.ui_node() | struct()]
        }

  defstruct [
    :id,
    :spacing,
    :padding,
    :width,
    :height,
    :max_width,
    :a11y,
    children: []
  ]

  @valid_option_keys ~w(spacing padding width height max_width a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{padding: Toddy.Type.Padding, a11y: Toddy.Type.A11y}
  end

  @doc "Creates a new keyed column struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing keyed column struct."
  @spec with_options(keyed_column :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = kc, []), do: kc

  def with_options(%__MODULE__{} = kc, opts) do
    Enum.reduce(opts, kc, fn
      {:spacing, v}, acc -> spacing(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:max_width, v}, acc -> max_width(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the spacing between children in pixels."
  @spec spacing(keyed_column :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = kc, spacing) when is_number(spacing),
    do: %{kc | spacing: spacing}

  @doc "Sets the padding inside the column."
  @spec padding(keyed_column :: t(), padding :: Toddy.Type.Padding.t()) :: t()
  def padding(%__MODULE__{} = kc, padding), do: %{kc | padding: padding}

  @doc "Sets the column width."
  @spec width(keyed_column :: t(), width :: Toddy.Type.Length.t()) :: t()
  def width(%__MODULE__{} = kc, width), do: %{kc | width: width}

  @doc "Sets the column height."
  @spec height(keyed_column :: t(), height :: Toddy.Type.Length.t()) :: t()
  def height(%__MODULE__{} = kc, height), do: %{kc | height: height}

  @doc "Sets the maximum width in pixels."
  @spec max_width(keyed_column :: t(), max_width :: number()) :: t()
  def max_width(%__MODULE__{} = kc, max_width) when is_number(max_width),
    do: %{kc | max_width: max_width}

  @doc "Appends a child to the keyed column."
  @spec push(keyed_column :: t(), child :: Toddy.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = kc, child), do: %{kc | children: [child | kc.children]}

  @doc "Appends multiple children to the keyed column."
  @spec extend(keyed_column :: t(), children :: [Toddy.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = kc, children),
    do: %{kc | children: Enum.reverse(children) ++ kc.children}

  @doc "Sets accessibility annotations."
  @spec a11y(keyed_column :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = kc, a11y), do: %{kc | a11y: A11y.cast(a11y)}

  @doc "Converts this keyed column struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(keyed_column :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = kc), do: Toddy.Widget.to_node(kc)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(kc) do
      props =
        %{}
        |> put_if(kc.spacing, :spacing)
        |> put_if(kc.padding, :padding)
        |> put_if(kc.width, :width)
        |> put_if(kc.height, :height)
        |> put_if(kc.max_width, :max_width)
        |> put_if(kc.a11y, :a11y)

      %{
        id: kc.id,
        type: "keyed_column",
        props: props,
        children: children_to_nodes(Enum.reverse(kc.children))
      }
    end
  end
end
