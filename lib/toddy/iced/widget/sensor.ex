defmodule Toddy.Iced.Widget.Sensor do
  @moduledoc """
  Sensor -- detects visibility and size changes on child content.

  ## Props

  - `delay` (non_neg_integer) -- delay in milliseconds before emitting events.
  - `anticipate` (number) -- distance in pixels to anticipate visibility (triggers events before
    the widget is fully in view).
  - `a11y` (map) -- accessibility overrides. See `Toddy.Iced.A11y`.

  ## Events

  - `%Sensor{type: :resize, id: id, width: w, height: h}` -- emitted on resize.
  - `%Sensor{type: :resize, id: "id:show", width: w, height: h}` -- emitted when child becomes visible.
  - `%Widget{type: :click, id: "id:hide"}` -- emitted when child becomes hidden.
  """

  alias Toddy.Iced.A11y
  alias Toddy.Iced.Widget.Build

  @type option ::
          {:delay, non_neg_integer()}
          | {:anticipate, number()}
          | {:a11y, Toddy.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          delay: non_neg_integer() | nil,
          anticipate: number() | nil,
          a11y: Toddy.Iced.A11y.t() | nil,
          children: [Toddy.Iced.ui_node() | struct()]
        }

  defstruct [:id, :delay, :anticipate, :a11y, children: []]

  @doc "Creates a new sensor struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id), do: %__MODULE__{id: id} |> with_options(opts)

  @doc "Applies keyword options to an existing sensor struct."
  @spec with_options(sensor :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = sensor, []), do: sensor

  def with_options(%__MODULE__{} = sensor, opts) do
    Enum.reduce(opts, sensor, fn
      {:delay, v}, acc -> delay(acc, v)
      {:anticipate, v}, acc -> anticipate(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the sensor delay in milliseconds."
  @spec delay(sensor :: t(), delay :: non_neg_integer()) :: t()
  def delay(%__MODULE__{} = sensor, delay) when is_integer(delay) and delay >= 0,
    do: %{sensor | delay: delay}

  @doc "Sets the anticipation distance in pixels."
  @spec anticipate(sensor :: t(), anticipate :: number()) :: t()
  def anticipate(%__MODULE__{} = sensor, anticipate) when is_number(anticipate),
    do: %{sensor | anticipate: anticipate}

  @doc "Appends a child to the sensor."
  @spec push(sensor :: t(), child :: Toddy.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = sensor, child), do: %{sensor | children: [child | sensor.children]}

  @doc "Appends multiple children to the sensor."
  @spec extend(sensor :: t(), children :: [Toddy.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = sensor, children),
    do: %{sensor | children: Enum.reverse(children) ++ sensor.children}

  @doc "Sets accessibility annotations."
  @spec a11y(sensor :: t(), a11y :: Toddy.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = sensor, a11y), do: %{sensor | a11y: A11y.cast(a11y)}

  @doc "Converts this sensor struct to a `ui_node()` map via the `Toddy.Iced.Widget` protocol."
  @spec build(sensor :: t()) :: Toddy.Iced.ui_node()
  def build(%__MODULE__{} = sensor), do: Toddy.Iced.Widget.to_node(sensor)

  defimpl Toddy.Iced.Widget do
    import Toddy.Iced.Widget.Build

    def to_node(sensor) do
      props =
        %{}
        |> put_if(sensor.delay, "delay")
        |> put_if(sensor.anticipate, "anticipate")
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
