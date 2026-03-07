defmodule Julep.Iced.Widget.Sensor do
  @moduledoc """
  Sensor -- detects visibility and size changes on child content.

  ## Props

  - `delay` (non_neg_integer) -- delay in milliseconds before emitting events.

  ## Events

  - `{:sensor_resize, id, width, height}` -- emitted on resize.
  - `{:sensor_resize, "id:show", width, height}` -- emitted when child becomes visible.
  - `{:click, "id:hide"}` -- emitted when child becomes hidden.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:delay, non_neg_integer()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          delay: non_neg_integer() | nil,
          a11y: Julep.Iced.A11y.t() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [:id, :delay, :a11y, children: []]

  @doc "Creates a new sensor struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id), do: %__MODULE__{id: id} |> with_options(opts)

  @doc "Applies keyword options to an existing sensor struct."
  @spec with_options(sensor :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = sensor, []), do: sensor

  def with_options(%__MODULE__{} = sensor, opts) do
    Enum.reduce(opts, sensor, fn
      {:delay, v}, acc -> delay(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the sensor delay in milliseconds."
  @spec delay(sensor :: t(), delay :: non_neg_integer()) :: t()
  def delay(%__MODULE__{} = sensor, delay), do: %{sensor | delay: delay}

  @doc "Appends a child to the sensor."
  @spec push(sensor :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = sensor, child), do: %{sensor | children: [child | sensor.children]}

  @doc "Appends multiple children to the sensor."
  @spec extend(sensor :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = sensor, children),
    do: %{sensor | children: Enum.reverse(children) ++ sensor.children}

  @doc "Sets accessibility annotations."
  @spec a11y(sensor :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = sensor, a11y), do: %{sensor | a11y: a11y}

  @doc "Converts this sensor struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(sensor :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = sensor), do: Julep.Iced.Widget.to_node(sensor)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(sensor) do
      props =
        %{}
        |> put_if(sensor.delay, "delay")
        |> put_if(sensor.a11y, "a11y")

      %{
        id: sensor.id,
        type: "sensor",
        props: props,
        children: children_to_nodes(Enum.reverse(sensor.children))
      }
    end
  end
end
