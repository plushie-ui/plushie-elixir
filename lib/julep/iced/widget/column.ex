defmodule Julep.Iced.Widget.Column do
  @moduledoc """
  Column layout -- arranges children vertically.

  ## Props

  - `spacing` (number) -- vertical space between children in pixels. Default: 0.
  - `padding` (number | map) -- padding inside the column. Accepts a uniform number
    or `%{top, right, bottom, left}` map. See `Julep.Iced.Padding`.
  - `width` (length) -- width of the column. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- height of the column. Default: shrink.
  - `max_width` (number) -- maximum width in pixels.
  - `align_x` (string) -- horizontal alignment of children: `"left"`, `"center"`, `"right"`.
  - `clip` (boolean) -- clip children that overflow. Default: false.
  - `wrap` (boolean) -- wrap children to next column when they overflow. Default: false.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:spacing, number()}
          | {:padding, Julep.Iced.Padding.t()}
          | {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:max_width, number()}
          | {:align_x, Julep.Iced.Alignment.t()}
          | {:clip, boolean()}
          | {:wrap, boolean()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          spacing: number() | nil,
          padding: Julep.Iced.Padding.t() | nil,
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          max_width: number() | nil,
          align_x: Julep.Iced.Alignment.t() | nil,
          clip: boolean() | nil,
          wrap: boolean() | nil,
          a11y: Julep.Iced.A11y.t() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :spacing,
    :padding,
    :width,
    :height,
    :max_width,
    :align_x,
    :clip,
    :wrap,
    :a11y,
    children: []
  ]

  @doc "Creates a new column struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing column struct."
  @spec with_options(column :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = col, []), do: col

  def with_options(%__MODULE__{} = col, opts) do
    Enum.reduce(opts, col, fn
      {:spacing, v}, acc -> spacing(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:max_width, v}, acc -> max_width(acc, v)
      {:align_x, v}, acc -> align_x(acc, v)
      {:clip, v}, acc -> clip(acc, v)
      {:wrap, v}, acc -> wrap(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the spacing between children in pixels."
  @spec spacing(column :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = col, spacing), do: %{col | spacing: spacing}

  @doc "Sets the padding inside the column."
  @spec padding(column :: t(), padding :: Julep.Iced.Padding.t()) :: t()
  def padding(%__MODULE__{} = col, padding), do: %{col | padding: padding}

  @doc "Sets the column width."
  @spec width(column :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = col, width), do: %{col | width: width}

  @doc "Sets the column height."
  @spec height(column :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = col, height), do: %{col | height: height}

  @doc "Sets the maximum width in pixels."
  @spec max_width(column :: t(), max_width :: number()) :: t()
  def max_width(%__MODULE__{} = col, max_width), do: %{col | max_width: max_width}

  @doc "Sets the horizontal alignment of children."
  @spec align_x(column :: t(), align_x :: Julep.Iced.Alignment.t()) :: t()
  def align_x(%__MODULE__{} = col, align_x), do: %{col | align_x: align_x}

  @doc "Sets whether children that overflow are clipped."
  @spec clip(column :: t(), clip :: boolean()) :: t()
  def clip(%__MODULE__{} = col, clip), do: %{col | clip: clip}

  @doc "Sets whether children wrap to the next column on overflow."
  @spec wrap(column :: t(), wrap :: boolean()) :: t()
  def wrap(%__MODULE__{} = col, wrap), do: %{col | wrap: wrap}

  @doc "Appends a child to the column."
  @spec push(column :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = col, child), do: %{col | children: [child | col.children]}

  @doc "Appends multiple children to the column."
  @spec extend(column :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = col, children),
    do: %{col | children: Enum.reverse(children) ++ col.children}

  @doc "Sets accessibility annotations."
  @spec a11y(column :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = col, a11y), do: %{col | a11y: a11y}

  @doc "Converts this column struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(column :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = col), do: Julep.Iced.Widget.to_node(col)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(col) do
      props =
        %{}
        |> put_if(col.spacing, "spacing")
        |> put_if(col.padding, "padding")
        |> put_if(col.width, "width")
        |> put_if(col.height, "height")
        |> put_if(col.max_width, "max_width")
        |> put_if(col.align_x, "align_x")
        |> put_if(col.clip, "clip")
        |> put_if(col.wrap, "wrap")
        |> put_if(col.a11y, "a11y")

      %{
        id: col.id,
        type: "column",
        props: props,
        children: children_to_nodes(Enum.reverse(col.children))
      }
    end
  end
end
