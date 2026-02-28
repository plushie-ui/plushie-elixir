defmodule Julep.Iced.Widget.Slider do
  @moduledoc """
  Slider -- horizontal range input.

  ## Props

  - `range` (list) -- `[min, max]` range as a two-element list. Default: `[0, 100]`.
  - `value` (number) -- current slider value. Defaults to range minimum.
  - `step` (number) -- step increment.
  - `width` (length) -- slider width. Default: fill. See `Julep.Iced.Length`.
  - `default` (number) -- default value (double-click resets to this).
  - `height` (number) -- slider track height in pixels.
  - `shift_step` (number) -- step increment when Shift is held.
  - `circular_handle` (boolean) -- use a circular handle instead of the
    default rectangular one. Default: false.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `{:slide, id, value}` -- emitted continuously while dragging.
  - `{:slide_release, id, value}` -- emitted when drag ends.
  """

  alias Julep.Iced.StyleMap
  alias Julep.Iced.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:step, number()}
          | {:shift_step, number()}
          | {:default, number()}
          | {:width, Julep.Iced.Length.t()}
          | {:height, number()}
          | {:circular_handle, boolean()}
          | {:style, style()}

  @type t :: %__MODULE__{
          id: String.t(),
          range: {number(), number()},
          value: number(),
          step: number() | nil,
          shift_step: number() | nil,
          default: number() | nil,
          width: Julep.Iced.Length.t() | nil,
          height: number() | nil,
          circular_handle: boolean() | nil,
          style: style() | nil
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
    :style
  ]

  @doc "Creates a new slider struct with the given range, value, and optional keyword opts."
  @spec new(
          id :: String.t(),
          range :: {number(), number()},
          value :: number(),
          opts :: [option()]
        ) ::
          t()
  def new(id, {_min, _max} = range, value, opts \\ []) do
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
      {:style, v}, acc -> style(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the step increment."
  @spec step(slider :: t(), step :: number()) :: t()
  def step(%__MODULE__{} = slider, step), do: %{slider | step: step}

  @doc "Sets the step increment when Shift is held."
  @spec shift_step(slider :: t(), shift_step :: number()) :: t()
  def shift_step(%__MODULE__{} = slider, shift_step), do: %{slider | shift_step: shift_step}

  @doc "Sets the default value (double-click resets to this)."
  @spec default(slider :: t(), default :: number()) :: t()
  def default(%__MODULE__{} = slider, default), do: %{slider | default: default}

  @doc "Sets the slider width."
  @spec width(slider :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = slider, width), do: %{slider | width: width}

  @doc "Sets the slider track height in pixels."
  @spec height(slider :: t(), height :: number()) :: t()
  def height(%__MODULE__{} = slider, height), do: %{slider | height: height}

  @doc "Sets whether the slider handle is circular."
  @spec circular_handle(slider :: t(), circular_handle :: boolean()) :: t()
  def circular_handle(%__MODULE__{} = slider, circular_handle),
    do: %{slider | circular_handle: circular_handle}

  @doc "Sets the slider style."
  @spec style(slider :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = slider, style), do: %{slider | style: style}

  @doc "Converts this slider struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(slider :: t()) :: Julep.Iced.ui_node()
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
        |> put_if(slider.circular_handle, "circular_handle")
        |> put_if(slider.style, "style")

      %{id: slider.id, type: "slider", props: props, children: []}
    end
  end
end
