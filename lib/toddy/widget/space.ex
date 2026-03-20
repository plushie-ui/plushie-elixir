defmodule Toddy.Widget.Space do
  @moduledoc """
  Empty space -- invisible spacer widget.

  ## Props

  - `width` (length) -- space width. Default: shrink. See `Toddy.Type.Length`.
  - `height` (length) -- space height. Default: shrink.
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
          a11y: Toddy.Type.A11y.t() | nil
        }

  defstruct [
    :id,
    :width,
    :height,
    :a11y
  ]

  @doc "Creates a new space struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing space struct."
  @spec with_options(space :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = space, []), do: space

  def with_options(%__MODULE__{} = space, opts) do
    Enum.reduce(opts, space, fn
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the space width."
  @spec width(space :: t(), width :: Toddy.Type.Length.t()) :: t()
  def width(%__MODULE__{} = space, width), do: %{space | width: width}

  @doc "Sets the space height."
  @spec height(space :: t(), height :: Toddy.Type.Length.t()) :: t()
  def height(%__MODULE__{} = space, height), do: %{space | height: height}

  @doc "Sets accessibility annotations."
  @spec a11y(space :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = space, a11y), do: %{space | a11y: A11y.cast(a11y)}

  @doc "Converts this space struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(space :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = space), do: Toddy.Widget.to_node(space)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(space) do
      props =
        %{}
        |> put_if(space.width, :width)
        |> put_if(space.height, :height)
        |> put_if(space.a11y, :a11y)

      %{id: space.id, type: "space", props: props, children: []}
    end
  end
end
