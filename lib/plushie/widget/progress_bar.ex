defmodule Plushie.Widget.ProgressBar do
  @moduledoc """
  Progress bar -- displays progress within a range.

  ## Props

  - `range` (list) -- `[min, max]` as a two-element list. Default: `[0, 100]`.
  - `value` (number) -- current progress value. Default: 0.
  - `width` (length) -- bar width. Default: fill. See `Plushie.Type.Length`.
  - `height` (length) -- bar height. Default: shrink.
  - `style` -- named preset atom (`:primary` (default), `:secondary`, `:success`,
    `:danger`, `:warning`) or `StyleMap.t()` for custom styling.
    See `Plushie.Type.StyleMap`.
  - `vertical` (boolean) -- when `true`, renders the progress bar vertically.
  - `label` (string) -- accessible label for the progress bar (e.g.
    "Upload progress"). Sits outside the `a11y` object. See "Widget-specific
    accessibility props" in `docs/accessibility.md`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  alias Plushie.Type.StyleMap
  alias Plushie.Widget.Build

  @presets [:primary, :secondary, :success, :danger, :warning]

  @type preset :: unquote(Enum.reduce(@presets, &{:|, [], [&1, &2]}))
  @type style :: preset() | StyleMap.t()

  @type option ::
          {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:style, style()}
          | {:vertical, boolean()}
          | {:label, String.t()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          range: {number(), number()},
          value: number(),
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          style: style() | nil,
          vertical: boolean() | nil,
          label: String.t() | nil,
          a11y: Plushie.Type.A11y.t() | nil
        }

  defstruct [:id, :range, :value, :width, :height, :style, :vertical, :label, :a11y]

  @valid_option_keys ~w(width height style vertical label a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{style: Plushie.Type.StyleMap, a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new progress bar struct with the given range, value, and optional keyword opts."
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

  @doc "Applies keyword options to an existing progress bar struct."
  @spec with_options(progress_bar :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = bar, []), do: bar

  def with_options(%__MODULE__{} = bar, opts) do
    Enum.reduce(opts, bar, fn
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:vertical, v}, acc -> vertical(acc, v)
      {:label, v}, acc -> label(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the progress bar width."
  @spec width(progress_bar :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = bar, width), do: %{bar | width: width}

  @doc "Sets the progress bar height."
  @spec height(progress_bar :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = bar, height), do: %{bar | height: height}

  @doc "Sets the progress bar style."
  @spec style(progress_bar :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = bar, %StyleMap{} = style), do: %{bar | style: style}
  def style(%__MODULE__{} = bar, style) when style in @presets, do: %{bar | style: style}

  @doc "Renders the progress bar vertically."
  @spec vertical(progress_bar :: t(), vertical :: boolean()) :: t()
  def vertical(%__MODULE__{} = bar, vertical) when is_boolean(vertical),
    do: %{bar | vertical: vertical}

  @doc "Sets the accessible label for the progress bar."
  @spec label(progress_bar :: t(), label :: String.t()) :: t()
  def label(%__MODULE__{} = bar, label) when is_binary(label),
    do: %{bar | label: label}

  @doc "Sets accessibility annotations."
  @spec a11y(progress_bar :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = bar, a11y), do: %{bar | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this progress bar struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(progress_bar :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = bar), do: Plushie.Widget.to_node(bar)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

    def to_node(bar) do
      props =
        %{}
        |> put_if(bar.range, :range)
        |> put_if(bar.value, :value)
        |> put_if(bar.width, :width)
        |> put_if(bar.height, :height)
        |> put_if(bar.style, :style)
        |> put_if(bar.vertical, :vertical)
        |> put_if(bar.label, :label)
        |> put_if(bar.a11y, :a11y)

      %{id: bar.id, type: "progress_bar", props: props, children: []}
    end
  end
end
