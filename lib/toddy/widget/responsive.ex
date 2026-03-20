defmodule Toddy.Widget.Responsive do
  @moduledoc """
  Responsive layout -- adapts to available size by reporting resize events.

  The renderer wraps child content in a sensor that sends
  `%Sensor{type: :resize, id: id, width: w, height: h}` events so the
  Elixir app can adjust its view based on the measured size.

  ## Props

  - `width` (length) -- container width. Default: fill. See `Toddy.Type.Length`.
  - `height` (length) -- container height. Default: fill.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Type.A11y`.
  """

  alias Toddy.Type.A11y
  alias Toddy.Widget.Build

  @type option ::
          {:width, Toddy.Type.Length.t()}
          | {:height, Toddy.Type.Length.t()}
          | {:a11y, Toddy.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          width: Toddy.Type.Length.t() | nil,
          height: Toddy.Type.Length.t() | nil,
          a11y: Toddy.Type.A11y.t() | nil,
          children: [Toddy.Widget.ui_node() | struct()]
        }

  defstruct [
    :id,
    :width,
    :height,
    :a11y,
    children: []
  ]

  @doc "Creates a new responsive struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing responsive struct."
  @spec with_options(responsive :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = r, []), do: r

  def with_options(%__MODULE__{} = r, opts) do
    Enum.reduce(opts, r, fn
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the container width."
  @spec width(responsive :: t(), width :: Toddy.Type.Length.t()) :: t()
  def width(%__MODULE__{} = r, width), do: %{r | width: width}

  @doc "Sets the container height."
  @spec height(responsive :: t(), height :: Toddy.Type.Length.t()) :: t()
  def height(%__MODULE__{} = r, height), do: %{r | height: height}

  @doc "Appends a child to the responsive container."
  @spec push(responsive :: t(), child :: Toddy.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = r, child), do: %{r | children: [child | r.children]}

  @doc "Appends multiple children to the responsive container."
  @spec extend(responsive :: t(), children :: [Toddy.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = r, children),
    do: %{r | children: Enum.reverse(children) ++ r.children}

  @doc "Sets accessibility annotations."
  @spec a11y(responsive :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = r, a11y), do: %{r | a11y: A11y.cast(a11y)}

  @doc "Converts this responsive struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(responsive :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = r), do: Toddy.Widget.to_node(r)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(r) do
      props =
        %{}
        |> put_if(r.width, "width")
        |> put_if(r.height, "height")
        |> put_if(r.a11y, "a11y")

      %{
        id: r.id,
        type: "responsive",
        props: props,
        children: children_to_nodes(Enum.reverse(r.children))
      }
    end
  end
end
