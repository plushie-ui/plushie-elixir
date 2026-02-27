defmodule Julep.Iced.Widget.Themer do
  @moduledoc """
  Per-subtree theme override -- applies a different theme to child widgets.

  ## Props

  - `theme` (string | map) -- a built-in theme name string (e.g. `"Dark"`, `"Nord"`)
    or a custom palette map. See `Julep.Iced.Theme`.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          theme: Julep.Iced.Theme.t(),
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :theme,
    children: []
  ]

  @doc "Creates a new themer struct with the given theme."
  @spec new(id :: String.t(), theme :: Julep.Iced.Theme.t()) :: t()
  def new(id, theme) when is_binary(id) do
    %__MODULE__{id: id, theme: theme}
  end

  @doc "Appends a child to the themer."
  @spec push(themer :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = t, child), do: %{t | children: t.children ++ [child]}

  @doc "Appends multiple children to the themer."
  @spec extend(themer :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = t, children), do: %{t | children: t.children ++ children}

  @doc "Converts this themer struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(themer :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = t), do: Julep.Iced.Widget.to_node(t)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(t) do
      props = %{"theme" => t.theme}

      %{id: t.id, type: "themer", props: props, children: children_to_nodes(t.children)}
    end
  end
end
