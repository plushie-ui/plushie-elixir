defmodule Toddy.Widget.Stack do
  @moduledoc """
  Stack layout -- layers children on top of each other.

  ## Props

  - `width` (length) -- stack width. Default: shrink. See `Toddy.Type.Length`.
  - `height` (length) -- stack height. Default: shrink.
  - `clip` (boolean) -- clip children that overflow. Default: false.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Type.A11y`.
  """

  alias Toddy.Type.A11y
  alias Toddy.Widget.Build

  @type option ::
          {:width, Toddy.Type.Length.t()}
          | {:height, Toddy.Type.Length.t()}
          | {:clip, boolean()}
          | {:a11y, Toddy.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          width: Toddy.Type.Length.t() | nil,
          height: Toddy.Type.Length.t() | nil,
          clip: boolean() | nil,
          a11y: Toddy.Type.A11y.t() | nil,
          children: [Toddy.Widget.ui_node() | struct()]
        }

  defstruct [
    :id,
    :width,
    :height,
    :clip,
    :a11y,
    children: []
  ]

  @valid_option_keys ~w(width height clip a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{a11y: Toddy.Type.A11y}
  end

  @doc "Creates a new stack struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing stack struct."
  @spec with_options(stack :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = stack, []), do: stack

  def with_options(%__MODULE__{} = stack, opts) do
    Enum.reduce(opts, stack, fn
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:clip, v}, acc -> clip(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the stack width."
  @spec width(stack :: t(), width :: Toddy.Type.Length.t()) :: t()
  def width(%__MODULE__{} = stack, width), do: %{stack | width: width}

  @doc "Sets the stack height."
  @spec height(stack :: t(), height :: Toddy.Type.Length.t()) :: t()
  def height(%__MODULE__{} = stack, height), do: %{stack | height: height}

  @doc "Sets whether children that overflow are clipped."
  @spec clip(stack :: t(), clip :: boolean()) :: t()
  def clip(%__MODULE__{} = stack, clip) when is_boolean(clip), do: %{stack | clip: clip}

  @doc "Appends a child to the stack."
  @spec push(stack :: t(), child :: Toddy.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = stack, child), do: %{stack | children: [child | stack.children]}

  @doc "Appends multiple children to the stack."
  @spec extend(stack :: t(), children :: [Toddy.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = stack, children),
    do: %{stack | children: Enum.reverse(children) ++ stack.children}

  @doc "Sets accessibility annotations."
  @spec a11y(stack :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = stack, a11y), do: %{stack | a11y: A11y.cast(a11y)}

  @doc "Converts this stack struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(stack :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = stack), do: Toddy.Widget.to_node(stack)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(stack) do
      props =
        %{}
        |> put_if(stack.width, :width)
        |> put_if(stack.height, :height)
        |> put_if(stack.clip, :clip)
        |> put_if(stack.a11y, :a11y)

      %{
        id: stack.id,
        type: "stack",
        props: props,
        children: children_to_nodes(Enum.reverse(stack.children))
      }
    end
  end
end
