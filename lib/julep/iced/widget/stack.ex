defmodule Julep.Iced.Widget.Stack do
  @moduledoc """
  Stack layout -- layers children on top of each other.

  ## Props

  - `width` (length) -- stack width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- stack height. Default: shrink.
  - `clip` (boolean) -- clip children that overflow. Default: false.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:clip, boolean()}

  @type t :: %__MODULE__{
          id: String.t(),
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          clip: boolean() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :width,
    :height,
    :clip,
    children: []
  ]

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
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the stack width."
  @spec width(stack :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = stack, width), do: %{stack | width: width}

  @doc "Sets the stack height."
  @spec height(stack :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = stack, height), do: %{stack | height: height}

  @doc "Sets whether children that overflow are clipped."
  @spec clip(stack :: t(), clip :: boolean()) :: t()
  def clip(%__MODULE__{} = stack, clip), do: %{stack | clip: clip}

  @doc "Appends a child to the stack."
  @spec push(stack :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = stack, child), do: %{stack | children: stack.children ++ [child]}

  @doc "Appends multiple children to the stack."
  @spec extend(stack :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = stack, children), do: %{stack | children: stack.children ++ children}

  @doc "Converts this stack struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(stack :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = stack), do: Julep.Iced.Widget.to_node(stack)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(stack) do
      props =
        %{}
        |> put_if(stack.width, "width")
        |> put_if(stack.height, "height")
        |> put_if(stack.clip, "clip")

      %{id: stack.id, type: "stack", props: props, children: children_to_nodes(stack.children)}
    end
  end
end
