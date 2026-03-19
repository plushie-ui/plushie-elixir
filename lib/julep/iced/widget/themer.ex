defmodule Julep.Iced.Widget.Themer do
  @moduledoc """
  Per-subtree theme override -- applies a different theme to child widgets.

  ## Props

  - `theme` -- a built-in theme atom (e.g. `:dark`, `:nord`) or a custom
    palette map. See `Julep.Iced.Theme`.
  - `a11y` (map) -- accessibility overrides. See `Julep.Iced.A11y`.
  """

  alias Julep.Iced.A11y

  @type t :: %__MODULE__{
          id: String.t(),
          theme: Julep.Iced.Theme.t(),
          a11y: Julep.Iced.A11y.t() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :theme,
    :a11y,
    children: []
  ]

  @doc "Creates a new themer struct with the given theme."
  @spec new(id :: String.t(), theme :: Julep.Iced.Theme.t()) :: t()
  def new(id, theme) when is_binary(id) do
    %__MODULE__{id: id, theme: theme}
  end

  @doc "Appends a child to the themer."
  @spec push(themer :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = t, child), do: %{t | children: [child | t.children]}

  @doc "Appends multiple children to the themer."
  @spec extend(themer :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = t, children),
    do: %{t | children: Enum.reverse(children) ++ t.children}

  @doc "Sets accessibility annotations."
  @spec a11y(themer :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = t, a11y), do: %{t | a11y: A11y.cast(a11y)}

  @doc "Converts this themer struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(themer :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = t), do: Julep.Iced.Widget.to_node(t)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(t) do
      props =
        %{}
        |> put_if(t.theme, "theme")
        |> put_if(t.a11y, "a11y")

      %{
        id: t.id,
        type: "themer",
        props: props,
        children: children_to_nodes(Enum.reverse(t.children))
      }
    end
  end
end
