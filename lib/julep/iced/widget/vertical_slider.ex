defmodule Julep.Iced.Widget.VerticalSlider do
  @moduledoc """
  Vertical slider -- vertical range input.

  ## Props

  - `range` (list) -- `[min, max]` range as a two-element list. Default: `[0, 100]`.
  - `value` (number) -- current slider value. Defaults to range minimum.
  - `step` (number) -- step increment.
  - `height` (length) -- slider height. Default: fill. See `Julep.Iced.Length`.
  - `default` (number) -- default value (double-click resets to this).
  - `shift_step` (number) -- step increment when Shift is held.
  - `rail_color` (hex color) -- color for the slider rail (both active and inactive portions).
  - `rail_width` (number) -- rail thickness in pixels.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `%Widget{type: :slide, id: id, value: value}` -- emitted continuously while dragging.
  - `%Widget{type: :slide_release, id: id, value: value}` -- emitted when drag ends.
  """

  alias Julep.Iced.A11y
  alias Julep.Iced.Color
  alias Julep.Iced.StyleMap
  alias Julep.Iced.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:step, number()}
          | {:shift_step, number()}
          | {:default, number()}
          | {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:rail_color, Julep.Iced.Color.t()}
          | {:rail_width, number()}
          | {:style, style()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          range: {number(), number()},
          value: number(),
          step: number() | nil,
          shift_step: number() | nil,
          default: number() | nil,
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          rail_color: Julep.Iced.Color.t() | nil,
          rail_width: number() | nil,
          style: style() | nil,
          a11y: Julep.Iced.A11y.t() | nil
        }

  defstruct [:id, :range, :value, :step, :shift_step, :default, :width, :height, :rail_color, :rail_width, :style, :a11y]

  @doc "Creates a new vertical slider struct with the given range, value, and optional keyword opts."
  @spec new(
          id :: String.t(),
          range :: {number(), number()},
          value :: number(),
          opts :: [option()]
        ) :: t()
  def new(id, {_min, _max} = range, value, opts \\ []) do
    %__MODULE__{id: id, range: range, value: value} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing vertical slider struct."
  @spec with_options(vertical_slider :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = slider, []), do: slider

  def with_options(%__MODULE__{} = slider, opts) do
    Enum.reduce(opts, slider, fn
      {:step, v}, acc -> step(acc, v)
      {:shift_step, v}, acc -> shift_step(acc, v)
      {:default, v}, acc -> __MODULE__.default(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:rail_color, v}, acc -> rail_color(acc, v)
      {:rail_width, v}, acc -> rail_width(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the step increment."
  @spec step(vertical_slider :: t(), step :: number()) :: t()
  def step(%__MODULE__{} = slider, step), do: %{slider | step: step}

  @doc "Sets the step increment when Shift is held."
  @spec shift_step(vertical_slider :: t(), shift_step :: number()) :: t()
  def shift_step(%__MODULE__{} = slider, shift_step), do: %{slider | shift_step: shift_step}

  @doc "Sets the default value (double-click resets to this)."
  @spec default(vertical_slider :: t(), default :: number()) :: t()
  def default(%__MODULE__{} = slider, default), do: %{slider | default: default}

  @doc "Sets the slider width."
  @spec width(vertical_slider :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = slider, width), do: %{slider | width: width}

  @doc "Sets the slider height."
  @spec height(vertical_slider :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = slider, height), do: %{slider | height: height}

  @doc "Sets the rail color."
  @spec rail_color(vertical_slider :: t(), rail_color :: Julep.Iced.Color.t()) :: t()
  def rail_color(%__MODULE__{} = slider, rail_color),
    do: %{slider | rail_color: Color.cast(rail_color)}

  @doc "Sets the rail width in pixels."
  @spec rail_width(vertical_slider :: t(), rail_width :: number()) :: t()
  def rail_width(%__MODULE__{} = slider, rail_width), do: %{slider | rail_width: rail_width}

  @doc "Sets the slider style."
  @spec style(vertical_slider :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = slider, style), do: %{slider | style: style}

  @doc "Sets accessibility annotations."
  @spec a11y(vertical_slider :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = slider, a11y), do: %{slider | a11y: A11y.cast(a11y)}

  @doc "Converts this vertical slider struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(vertical_slider :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = slider), do: Julep.Iced.Widget.to_node(slider)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(slider) do
      props =
        %{}
        |> put_if(slider.value, "value")
        |> put_if(slider.range, "range")
        |> put_if(slider.step, "step")
        |> put_if(slider.shift_step, "shift_step")
        |> put_if(slider.default, "default")
        |> put_if(slider.width, "width")
        |> put_if(slider.height, "height")
        |> put_if(slider.rail_color, "rail_color")
        |> put_if(slider.rail_width, "rail_width")
        |> put_if(slider.style, "style")
        |> put_if(slider.a11y, "a11y")

      %{id: slider.id, type: "vertical_slider", props: props, children: []}
    end
  end
end
