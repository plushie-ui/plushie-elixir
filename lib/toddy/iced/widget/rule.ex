defmodule Toddy.Iced.Widget.Rule do
  @moduledoc """
  Horizontal or vertical rule (divider line).

  ## Props

  - `height` (number) -- line thickness in pixels (for horizontal rules). Default: 1.
  - `width` (number) -- line thickness in pixels (for vertical rules). Also accepts `thickness`.
  - `direction` -- `:horizontal` (default) or `:vertical`. See `Toddy.Iced.Direction`.
  - `style` -- named preset atom (`:default`, `:weak`) or `StyleMap.t()` for
    custom styling. See `Toddy.Iced.StyleMap`.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Iced.A11y`.
  """

  alias Toddy.Iced.A11y
  alias Toddy.Iced.StyleMap
  alias Toddy.Iced.Widget.Build

  @presets [:default, :weak]

  @type preset :: unquote(Enum.reduce(@presets, &{:|, [], [&1, &2]}))
  @type style :: preset() | StyleMap.t()

  @type option ::
          {:height, number()}
          | {:width, number()}
          | {:direction, Toddy.Iced.Direction.t()}
          | {:style, style()}
          | {:a11y, Toddy.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          height: number() | nil,
          width: number() | nil,
          direction: Toddy.Iced.Direction.t() | nil,
          style: style() | nil,
          a11y: Toddy.Iced.A11y.t() | nil
        }

  defstruct [:id, :height, :width, :direction, :style, :a11y]

  @doc "Creates a new rule struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing rule struct."
  @spec with_options(rule :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = rule, []), do: rule

  def with_options(%__MODULE__{} = rule, opts) do
    Enum.reduce(opts, rule, fn
      {:height, v}, acc -> height(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:direction, v}, acc -> direction(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the rule height (thickness for horizontal rules)."
  @spec height(rule :: t(), height :: number()) :: t()
  def height(%__MODULE__{} = rule, height) when is_number(height), do: %{rule | height: height}

  @doc "Sets the rule width (thickness for vertical rules)."
  @spec width(rule :: t(), width :: number()) :: t()
  def width(%__MODULE__{} = rule, width) when is_number(width), do: %{rule | width: width}

  @doc "Sets the rule direction."
  @spec direction(rule :: t(), direction :: Toddy.Iced.Direction.t()) :: t()
  def direction(%__MODULE__{} = rule, direction), do: %{rule | direction: direction}

  @doc "Sets the rule style."
  @spec style(rule :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = rule, %StyleMap{} = style), do: %{rule | style: style}
  def style(%__MODULE__{} = rule, style) when style in @presets, do: %{rule | style: style}

  @doc "Sets accessibility annotations."
  @spec a11y(rule :: t(), a11y :: Toddy.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = rule, a11y), do: %{rule | a11y: A11y.cast(a11y)}

  @doc "Converts this rule struct to a `ui_node()` map via the `Toddy.Iced.Widget` protocol."
  @spec build(rule :: t()) :: Toddy.Iced.ui_node()
  def build(%__MODULE__{} = rule), do: Toddy.Iced.Widget.to_node(rule)

  defimpl Toddy.Iced.Widget do
    import Toddy.Iced.Widget.Build

    def to_node(rule) do
      props =
        %{}
        |> put_if(rule.height, "height")
        |> put_if(rule.width, "width")
        |> put_if(rule.direction, "direction")
        |> put_if(rule.style, "style")
        |> put_if(rule.a11y, "a11y")

      %{id: rule.id, type: "rule", props: props, children: []}
    end
  end
end
