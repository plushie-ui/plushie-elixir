defmodule Julep.Iced.Widget.MouseArea do
  @moduledoc """
  Mouse area -- captures mouse events on child content.

  Wraps child content and emits click events for various mouse buttons.

  ## Props

  No additional props beyond children. Events are derived from the node ID.

  ## Events

  - `{:click, id}` -- left mouse button pressed.
  - `{:click, "id:release"}` -- left mouse button released.
  - `{:click, "id:middle"}` -- middle mouse button pressed.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [:id, children: []]

  @doc "Creates a new mouse area struct."
  @spec new(id :: String.t()) :: t()
  def new(id) when is_binary(id), do: %__MODULE__{id: id}

  @doc "Appends a child to the mouse area."
  @spec push(mouse_area :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = ma, child), do: %{ma | children: ma.children ++ [child]}

  @doc "Appends multiple children to the mouse area."
  @spec extend(mouse_area :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = ma, children), do: %{ma | children: ma.children ++ children}

  @doc "Converts this mouse area struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(mouse_area :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = ma), do: Julep.Iced.Widget.to_node(ma)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(ma) do
      %{id: ma.id, type: "mouse_area", props: %{}, children: children_to_nodes(ma.children)}
    end
  end
end
