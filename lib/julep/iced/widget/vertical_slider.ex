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
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `{:slide, id, value}` -- emitted continuously while dragging.
  - `{:slide_release, id, value}` -- emitted when drag ends.
  """

  alias Julep.Iced.Widget.Build

  @type style :: :default

  @type option ::
          {:step, number()}
          | {:shift_step, number()}
          | {:default, number()}
          | {:height, Julep.Iced.Length.t()}
          | {:style, style()}

  @type t :: %__MODULE__{
          id: String.t(),
          range: {number(), number()},
          value: number(),
          step: number() | nil,
          shift_step: number() | nil,
          default: number() | nil,
          height: Julep.Iced.Length.t() | nil,
          style: style() | nil
        }

  defstruct [:id, :range, :value, :step, :shift_step, :default, :height, :style]

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
      {:height, v}, acc -> height(acc, v)
      {:style, v}, acc -> style(acc, v)
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

  @doc "Sets the slider height."
  @spec height(vertical_slider :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = slider, height), do: %{slider | height: height}

  @doc "Sets the slider style."
  @spec style(vertical_slider :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = slider, style), do: %{slider | style: style}

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
        |> put_if(slider.height, "height")
        |> put_if(slider.style, "style")

      %{id: slider.id, type: "vertical_slider", props: props, children: []}
    end
  end
end
