defmodule Plushie.Widget.Sensor do
  @moduledoc """
  Sensor -- detects visibility and size changes on child content.

  ## Props

  - `delay` (non_neg_integer) -- delay in milliseconds before emitting events.
  - `anticipate` (number) -- distance in pixels to anticipate visibility (triggers events before
    the widget is fully in view).
  - `on_resize` (atom | string) -- event tag for resize events.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  - `%Sensor{type: :resize, id: id, width: w, height: h}` -- emitted on resize.
  - `%Sensor{type: :resize, id: "id:show", width: w, height: h}` -- emitted when child becomes visible.
  - `%WidgetEvent{type: :click, id: "id:hide"}` -- emitted when child becomes hidden.
  """

  alias Plushie.Widget.Build

  @type option ::
          {:delay, non_neg_integer()}
          | {:anticipate, number()}
          | {:on_resize, atom() | String.t()}
          | {:event_rate, pos_integer()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          delay: non_neg_integer() | nil,
          anticipate: number() | nil,
          on_resize: String.t() | nil,
          event_rate: pos_integer() | nil,
          a11y: Plushie.Type.A11y.t() | nil,
          children: [Plushie.Widget.ui_node() | struct()]
        }

  defstruct [:id, :delay, :anticipate, :on_resize, :event_rate, :a11y, children: []]

  @valid_option_keys ~w(delay anticipate on_resize event_rate a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{a11y: Plushie.Type.A11y}
  end

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
      {:on_resize, v}, acc -> on_resize(acc, v)
      {:event_rate, v}, acc -> event_rate(acc, v)
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

  @doc "Sets the event tag for resize events."
  @spec on_resize(sensor :: t(), tag :: atom() | String.t()) :: t()
  def on_resize(%__MODULE__{} = sensor, tag) when is_atom(tag),
    do: %{sensor | on_resize: Atom.to_string(tag)}

  def on_resize(%__MODULE__{} = sensor, tag) when is_binary(tag),
    do: %{sensor | on_resize: tag}

  @doc "Appends a child to the sensor."
  @spec push(sensor :: t(), child :: Plushie.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = sensor, child), do: %{sensor | children: [child | sensor.children]}

  @doc "Appends multiple children to the sensor."
  @spec extend(sensor :: t(), children :: [Plushie.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = sensor, children),
    do: %{sensor | children: Enum.reverse(children) ++ sensor.children}

  @doc "Sets the maximum event rate (events per second) for this widget's coalescable events."
  @spec event_rate(sensor :: t(), rate :: pos_integer()) :: t()
  def event_rate(%__MODULE__{} = sensor, rate) when is_integer(rate) and rate >= 0,
    do: %{sensor | event_rate: rate}

  @doc "Sets accessibility annotations."
  @spec a11y(sensor :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = sensor, a11y), do: %{sensor | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this sensor struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(sensor :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = sensor), do: Plushie.Widget.to_node(sensor)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

    def to_node(sensor) do
      props =
        %{}
        |> put_if(sensor.delay, :delay)
        |> put_if(sensor.anticipate, :anticipate)
        |> put_if(sensor.on_resize, :on_resize)
        |> put_if(sensor.event_rate, :event_rate)
        |> put_if(sensor.a11y, :a11y)

      %{
        id: sensor.id,
        type: "sensor",
        props: props,
        children: children_to_nodes(Enum.reverse(sensor.children))
      }
    end
  end
end
