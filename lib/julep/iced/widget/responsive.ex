defmodule Julep.Iced.Widget.Responsive do
  @moduledoc """
  Responsive layout -- adapts to available size by reporting resize events.

  The renderer wraps child content in a sensor that sends `{:sensor_resize, id, w, h}`
  events so the Elixir app can adjust its view based on the measured size.

  ## Props

  - `width` (length) -- container width. Default: fill. See `Julep.Iced.Length`.
  - `height` (length) -- container height. Default: fill.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :width,
    :height,
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
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the container width."
  @spec width(responsive :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = r, width), do: %{r | width: width}

  @doc "Sets the container height."
  @spec height(responsive :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = r, height), do: %{r | height: height}

  @doc "Appends a child to the responsive container."
  @spec push(responsive :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = r, child), do: %{r | children: r.children ++ [child]}

  @doc "Appends multiple children to the responsive container."
  @spec extend(responsive :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = r, children), do: %{r | children: r.children ++ children}

  @doc "Converts this responsive struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(responsive :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = r), do: Julep.Iced.Widget.to_node(r)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(r) do
      props =
        %{}
        |> put_if(r.width, "width")
        |> put_if(r.height, "height")

      %{id: r.id, type: "responsive", props: props, children: children_to_nodes(r.children)}
    end
  end
end
