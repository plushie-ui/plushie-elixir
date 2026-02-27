defmodule Julep.Iced.Widget.Sensor do
  @moduledoc """
  Sensor -- detects visibility and size changes on child content.

  ## Props

  No additional props beyond children. Events are derived from the node ID.

  ## Events

  - `{:sensor_resize, id, width, height}` -- emitted on resize.
  - `{:sensor_resize, "id:show", width, height}` -- emitted when child becomes visible.
  - `{:click, "id:hide"}` -- emitted when child becomes hidden.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [:id, children: []]

  @doc "Creates a new sensor struct."
  @spec new(id :: String.t()) :: t()
  def new(id) when is_binary(id), do: %__MODULE__{id: id}

  @doc "Appends a child to the sensor."
  @spec push(sensor :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = sensor, child), do: %{sensor | children: sensor.children ++ [child]}

  @doc "Appends multiple children to the sensor."
  @spec extend(sensor :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = sensor, children),
    do: %{sensor | children: sensor.children ++ children}

  @doc "Converts this sensor struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(sensor :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = sensor), do: Julep.Iced.Widget.to_node(sensor)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(sensor) do
      %{
        id: sensor.id,
        type: "sensor",
        props: %{},
        children: children_to_nodes(sensor.children)
      }
    end
  end
end
