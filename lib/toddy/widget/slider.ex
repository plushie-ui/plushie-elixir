defmodule Toddy.Widget.Slider do
  @moduledoc """
  Slider -- horizontal range input.

  ## Props

  - `range` (list) -- `[min, max]` range as a two-element list. Default: `[0, 100]`.
  - `value` (number) -- current slider value. Defaults to range minimum.
  - `step` (number) -- step increment.
  - `width` (length) -- slider width. Default: fill. See `Toddy.Type.Length`.
  - `default` (number) -- default value (double-click resets to this).
  - `height` (number) -- slider track height in pixels.
  - `shift_step` (number) -- step increment when Shift is held.
  - `circular_handle` (boolean) -- use a circular handle instead of the
    default rectangular one. Default: false.
  - `rail_color` (hex color) -- color for the slider rail (both active and inactive portions).
  - `rail_width` (number) -- rail thickness in pixels.
  - `style` -- `:default` or `StyleMap.t()` for custom styling. See `Toddy.Type.StyleMap`.
  - `label` (string) -- accessible label for the slider (e.g. "Volume").
    Sits outside the `a11y` object. See "Widget-specific accessibility props"
    in `docs/accessibility.md`.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Type.A11y`.

  ## Events

  - `%Widget{type: :slide, id: id, value: value}` -- emitted continuously while dragging.
  - `%Widget{type: :slide_release, id: id, value: value}` -- emitted when drag ends.
  """

  alias Toddy.Type.A11y
  alias Toddy.Type.Color
  alias Toddy.Type.StyleMap
  alias Toddy.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:step, number()}
          | {:shift_step, number()}
          | {:default, number()}
          | {:width, Toddy.Type.Length.t()}
          | {:height, number()}
          | {:circular_handle, boolean()}
          | {:rail_color, Toddy.Type.Color.input()}
          | {:rail_width, number()}
          | {:style, style()}
          | {:label, String.t()}
          | {:a11y, Toddy.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          range: {number(), number()},
          value: number(),
          step: number() | nil,
          shift_step: number() | nil,
          default: number() | nil,
          width: Toddy.Type.Length.t() | nil,
          height: number() | nil,
          circular_handle: boolean() | nil,
          rail_color: Toddy.Type.Color.t() | nil,
          rail_width: number() | nil,
          style: style() | nil,
          label: String.t() | nil,
          a11y: Toddy.Type.A11y.t() | nil
        }

  defstruct [
    :id,
    :range,
    :value,
    :step,
    :shift_step,
    :default,
    :width,
    :height,
    :circular_handle,
    :rail_color,
    :rail_width,
    :style,
    :label,
    :a11y
  ]

  @doc "Creates a new slider struct with the given range, value, and optional keyword opts."
  @spec new(
          id :: String.t(),
          range :: {number(), number()},
          value :: number(),
          opts :: [option()]
        ) ::
          t()
  def new(id, {min, max} = range, value, opts \\ [])
      when is_binary(id) and is_number(min) and is_number(max) and is_number(value) do
    %__MODULE__{id: id, range: range, value: value} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing slider struct."
  @spec with_options(slider :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = slider, []), do: slider

  def with_options(%__MODULE__{} = slider, opts) do
    Enum.reduce(opts, slider, fn
      {:step, v}, acc -> step(acc, v)
      {:shift_step, v}, acc -> shift_step(acc, v)
      {:default, v}, acc -> __MODULE__.default(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:circular_handle, v}, acc -> circular_handle(acc, v)
      {:rail_color, v}, acc -> rail_color(acc, v)
      {:rail_width, v}, acc -> rail_width(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:label, v}, acc -> label(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the step increment."
  @spec step(slider :: t(), step :: number()) :: t()
  def step(%__MODULE__{} = slider, step) when is_number(step), do: %{slider | step: step}

  @doc "Sets the step increment when Shift is held."
  @spec shift_step(slider :: t(), shift_step :: number()) :: t()
  def shift_step(%__MODULE__{} = slider, shift_step) when is_number(shift_step),
    do: %{slider | shift_step: shift_step}

  @doc "Sets the default value (double-click resets to this)."
  @spec default(slider :: t(), default :: number()) :: t()
  def default(%__MODULE__{} = slider, default) when is_number(default),
    do: %{slider | default: default}

  @doc "Sets the slider width."
  @spec width(slider :: t(), width :: Toddy.Type.Length.t()) :: t()
  def width(%__MODULE__{} = slider, width), do: %{slider | width: width}

  @doc "Sets the slider track height in pixels."
  @spec height(slider :: t(), height :: number()) :: t()
  def height(%__MODULE__{} = slider, height) when is_number(height),
    do: %{slider | height: height}

  @doc "Sets whether the slider handle is circular."
  @spec circular_handle(slider :: t(), circular_handle :: boolean()) :: t()
  def circular_handle(%__MODULE__{} = slider, circular_handle) when is_boolean(circular_handle),
    do: %{slider | circular_handle: circular_handle}

  @doc "Sets the rail color."
  @spec rail_color(slider :: t(), rail_color :: Toddy.Type.Color.input()) :: t()
  def rail_color(%__MODULE__{} = slider, rail_color),
    do: %{slider | rail_color: Color.cast(rail_color)}

  @doc "Sets the rail width in pixels."
  @spec rail_width(slider :: t(), rail_width :: number()) :: t()
  def rail_width(%__MODULE__{} = slider, rail_width) when is_number(rail_width),
    do: %{slider | rail_width: rail_width}

  @doc "Sets the accessible label for the slider."
  @spec label(slider :: t(), label :: String.t()) :: t()
  def label(%__MODULE__{} = slider, label) when is_binary(label),
    do: %{slider | label: label}

  @doc "Sets the slider style."
  @spec style(slider :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = slider, %StyleMap{} = style), do: %{slider | style: style}
  def style(%__MODULE__{} = slider, :default), do: %{slider | style: :default}

  @doc "Sets accessibility annotations."
  @spec a11y(slider :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = slider, a11y), do: %{slider | a11y: A11y.cast(a11y)}

  @doc "Converts this slider struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(slider :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = slider), do: Toddy.Widget.to_node(slider)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(slider) do
      props =
        %{}
        |> put_if(slider.value, :value)
        |> put_if(slider.range, :range)
        |> put_if(slider.step, :step)
        |> put_if(slider.shift_step, :shift_step)
        |> put_if(slider.default, :default)
        |> put_if(slider.width, :width)
        |> put_if(slider.height, :height)
        |> put_if(slider.circular_handle, :circular_handle)
        |> put_if(slider.rail_color, :rail_color)
        |> put_if(slider.rail_width, :rail_width)
        |> put_if(slider.style, :style)
        |> put_if(slider.label, :label)
        |> put_if(slider.a11y, :a11y)

      %{id: slider.id, type: "slider", props: props, children: []}
    end
  end
end
