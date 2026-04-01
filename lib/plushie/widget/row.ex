defmodule Plushie.Widget.Row do
  @moduledoc """
  Row layout -- arranges children horizontally.

  ## Props

  - `spacing` (number) -- horizontal space between children in pixels. Default: 0.
  - `padding` (number | map) -- padding inside the row. See `Plushie.Type.Padding`.
  - `width` (length) -- width of the row. Default: shrink. See `Plushie.Type.Length`.
  - `height` (length) -- height of the row. Default: shrink.
  - `align_y` -- vertical alignment of children: `:top`, `:center`, `:bottom`. See `Plushie.Type.Alignment`.
  - `max_width` (number) -- maximum width of the row in pixels.
  - `clip` (boolean) -- clip children that overflow. Default: false.
  - `wrap` (boolean) -- wrap children to next row when they overflow. Default: false.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  alias Plushie.Widget.Build

  @type option ::
          {:spacing, number()}
          | {:padding, Plushie.Type.Padding.t()}
          | {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:align_y, Plushie.Type.Alignment.t()}
          | {:max_width, number()}
          | {:clip, boolean()}
          | {:wrap, boolean()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          spacing: number() | nil,
          padding: Plushie.Type.Padding.t() | nil,
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          align_y: Plushie.Type.Alignment.t() | nil,
          max_width: number() | nil,
          clip: boolean() | nil,
          wrap: boolean() | nil,
          a11y: Plushie.Type.A11y.t() | nil,
          children: [Plushie.Widget.child()]
        }

  defstruct [
    :id,
    :spacing,
    :padding,
    :width,
    :height,
    :align_y,
    :max_width,
    :clip,
    :wrap,
    :a11y,
    children: []
  ]

  @valid_option_keys ~w(spacing padding width height align_y max_width clip wrap a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{padding: Plushie.Type.Padding, a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new row struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing row struct."
  @spec with_options(row :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = row, []), do: row

  def with_options(%__MODULE__{} = row, opts) do
    Enum.reduce(opts, row, fn
      {:spacing, v}, acc -> spacing(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:align_y, v}, acc -> align_y(acc, v)
      {:max_width, v}, acc -> max_width(acc, v)
      {:clip, v}, acc -> clip(acc, v)
      {:wrap, v}, acc -> wrap(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the spacing between children in pixels."
  @spec spacing(row :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = row, spacing) when is_number(spacing), do: %{row | spacing: spacing}

  @doc "Sets the padding inside the row."
  @spec padding(row :: t(), padding :: Plushie.Type.Padding.t()) :: t()
  def padding(%__MODULE__{} = row, padding), do: %{row | padding: padding}

  @doc "Sets the row width."
  @spec width(row :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = row, width), do: %{row | width: width}

  @doc "Sets the row height."
  @spec height(row :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = row, height), do: %{row | height: height}

  @doc "Sets the vertical alignment of children."
  @spec align_y(row :: t(), align_y :: Plushie.Type.Alignment.t()) :: t()
  def align_y(%__MODULE__{} = row, align_y), do: %{row | align_y: align_y}

  @doc "Sets the maximum width of the row in pixels."
  @spec max_width(row :: t(), max_width :: number()) :: t()
  def max_width(%__MODULE__{} = row, max_width) when is_number(max_width),
    do: %{row | max_width: max_width}

  @doc "Sets whether children that overflow are clipped."
  @spec clip(row :: t(), clip :: boolean()) :: t()
  def clip(%__MODULE__{} = row, clip) when is_boolean(clip), do: %{row | clip: clip}

  @doc "Sets whether children wrap to the next row on overflow."
  @spec wrap(row :: t(), wrap :: boolean()) :: t()
  def wrap(%__MODULE__{} = row, wrap) when is_boolean(wrap), do: %{row | wrap: wrap}

  @doc "Appends a child to the row."
  @spec push(row :: t(), child :: Plushie.Widget.child()) :: t()
  def push(%__MODULE__{} = row, child), do: %{row | children: [child | row.children]}

  @doc "Appends multiple children to the row."
  @spec extend(row :: t(), children :: [Plushie.Widget.child()]) ::
          t()
  def extend(%__MODULE__{} = row, children),
    do: %{row | children: Enum.reverse(children) ++ row.children}

  @doc "Sets accessibility annotations."
  @spec a11y(row :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = row, a11y), do: %{row | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this row struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(row :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = row), do: Plushie.Widget.to_node(row)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

    def to_node(row) do
      props =
        %{}
        |> put_if(row.spacing, :spacing)
        |> put_if(row.padding, :padding)
        |> put_if(row.width, :width)
        |> put_if(row.height, :height)
        |> put_if(row.align_y, :align_y)
        |> put_if(row.max_width, :max_width)
        |> put_if(row.clip, :clip)
        |> put_if(row.wrap, :wrap)
        |> put_if(row.a11y, :a11y)

      %{
        id: row.id,
        type: "row",
        props: props,
        children: children_to_nodes(Enum.reverse(row.children))
      }
    end
  end
end
