defmodule Julep.Iced.Widget.Rule do
  @moduledoc """
  Horizontal or vertical rule (divider line).

  ## Props

  - `height` (number) -- line thickness in pixels (for horizontal rules). Default: 1.
  - `width` (number) -- line thickness in pixels (for vertical rules). Also accepts `thickness`.
  - `direction` (string) -- `"horizontal"` (default) or `"vertical"`.
  - `style` (string) -- named style: `"default"` or `"weak"`.
  """

  alias Julep.Iced.Widget.Build

  @type style :: :default | :weak

  @type option ::
          {:height, number()}
          | {:width, number()}
          | {:direction, atom()}
          | {:style, style()}

  @type t :: %__MODULE__{
          id: String.t(),
          height: number() | nil,
          width: number() | nil,
          direction: atom() | nil,
          style: style() | nil
        }

  defstruct [:id, :height, :width, :direction, :style]

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
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the rule height (thickness for horizontal rules)."
  @spec height(rule :: t(), height :: number()) :: t()
  def height(%__MODULE__{} = rule, height), do: %{rule | height: height}

  @doc "Sets the rule width (thickness for vertical rules)."
  @spec width(rule :: t(), width :: number()) :: t()
  def width(%__MODULE__{} = rule, width), do: %{rule | width: width}

  @doc "Sets the rule direction."
  @spec direction(rule :: t(), direction :: atom()) :: t()
  def direction(%__MODULE__{} = rule, direction), do: %{rule | direction: direction}

  @doc "Sets the rule style."
  @spec style(rule :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = rule, style), do: %{rule | style: style}

  @doc "Converts this rule struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(rule :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = rule), do: Julep.Iced.Widget.to_node(rule)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(rule) do
      props =
        %{}
        |> put_if(rule.height, "height")
        |> put_if(rule.width, "width")
        |> put_if(rule.direction, "direction", &to_string/1)
        |> put_if(rule.style, "style", &to_string/1)

      %{id: rule.id, type: "rule", props: props, children: []}
    end
  end
end
