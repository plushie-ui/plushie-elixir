defmodule Julep.Iced.Widget.ProgressBar do
  @moduledoc """
  Progress bar -- displays progress within a range.

  ## Props

  - `range` (list) -- `[min, max]` as a two-element list. Default: `[0, 100]`.
  - `value` (number) -- current progress value. Default: 0.
  - `width` (length) -- bar width. Default: fill. See `Julep.Iced.Length`.
  - `height` (length) -- bar height. Default: shrink.
  - `style` -- named preset atom (`:primary` (default), `:secondary`, `:success`,
    `:danger`, `:warning`) or `StyleMap.t()` for custom styling.
    See `Julep.Iced.StyleMap`.
  - `vertical` (boolean) -- when `true`, renders the progress bar vertically.
  """

  alias Julep.Iced.A11y
  alias Julep.Iced.StyleMap
  alias Julep.Iced.Widget.Build

  @type style :: :primary | :secondary | :success | :danger | :warning | StyleMap.t()

  @type option ::
          {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:style, style()}
          | {:vertical, boolean()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          range: {number(), number()},
          value: number(),
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          style: style() | nil,
          vertical: boolean() | nil,
          a11y: Julep.Iced.A11y.t() | nil
        }

  defstruct [:id, :range, :value, :width, :height, :style, :vertical, :a11y]

  @doc "Creates a new progress bar struct with the given range, value, and optional keyword opts."
  @spec new(
          id :: String.t(),
          range :: {number(), number()},
          value :: number(),
          opts :: [option()]
        ) ::
          t()
  def new(id, range, value, opts \\ []) when is_binary(id) and is_tuple(range) do
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
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the progress bar width."
  @spec width(progress_bar :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = bar, width), do: %{bar | width: width}

  @doc "Sets the progress bar height."
  @spec height(progress_bar :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = bar, height), do: %{bar | height: height}

  @doc "Sets the progress bar style."
  @spec style(progress_bar :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = bar, style), do: %{bar | style: style}

  @doc "Renders the progress bar vertically."
  @spec vertical(progress_bar :: t(), vertical :: boolean()) :: t()
  def vertical(%__MODULE__{} = bar, vertical), do: %{bar | vertical: vertical}

  @doc "Sets accessibility annotations."
  @spec a11y(progress_bar :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = bar, a11y), do: %{bar | a11y: A11y.cast(a11y)}

  @doc "Converts this progress bar struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(progress_bar :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = bar), do: Julep.Iced.Widget.to_node(bar)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(bar) do
      {min, max} = bar.range

      props =
        %{}
        |> put_if([min, max], "range")
        |> put_if(bar.value, "value")
        |> put_if(bar.width, "width")
        |> put_if(bar.height, "height")
        |> put_if(bar.style, "style")
        |> put_if(bar.vertical, "vertical")
        |> put_if(bar.a11y, "a11y")

      %{id: bar.id, type: "progress_bar", props: props, children: []}
    end
  end
end
