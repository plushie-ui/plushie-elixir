defmodule Toddy.Widget.Themer do
  @moduledoc """
  Per-subtree theme override -- applies a different theme to child widgets.

  ## Props

  - `theme` -- a built-in theme atom (e.g. `:dark`, `:nord`) or a custom
    palette map. See `Toddy.Type.Theme`.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Type.A11y`.
  """

  alias Toddy.Type.A11y
  alias Toddy.Widget.Build

  @type option ::
          {:theme, Toddy.Type.Theme.t()}
          | {:a11y, Toddy.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          theme: Toddy.Type.Theme.t(),
          a11y: Toddy.Type.A11y.t() | nil,
          children: [Toddy.Widget.ui_node() | struct()]
        }

  defstruct [
    :id,
    :theme,
    :a11y,
    children: []
  ]

  @valid_option_keys ~w(theme a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{a11y: Toddy.Type.A11y}
  end

  @doc "Creates a new themer struct with the given theme."
  @spec new(id :: String.t(), theme_or_opts :: Toddy.Type.Theme.t() | [option()]) :: t()
  def new(id, opts) when is_binary(id) and is_list(opts) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  def new(id, theme) when is_binary(id) do
    %__MODULE__{id: id, theme: theme}
  end

  @doc "Applies keyword options to an existing themer struct."
  @spec with_options(themer :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = t, []), do: t

  def with_options(%__MODULE__{} = t, opts) do
    Enum.reduce(opts, t, fn
      {:theme, v}, acc -> %{acc | theme: v}
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Appends a child to the themer."
  @spec push(themer :: t(), child :: Toddy.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = t, child), do: %{t | children: [child | t.children]}

  @doc "Appends multiple children to the themer."
  @spec extend(themer :: t(), children :: [Toddy.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = t, children),
    do: %{t | children: Enum.reverse(children) ++ t.children}

  @doc "Sets accessibility annotations."
  @spec a11y(themer :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = t, a11y), do: %{t | a11y: A11y.cast(a11y)}

  @doc "Converts this themer struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(themer :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = t), do: Toddy.Widget.to_node(t)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(t) do
      props =
        %{}
        |> put_if(t.theme, :theme)
        |> put_if(t.a11y, :a11y)

      %{
        id: t.id,
        type: "themer",
        props: props,
        children: children_to_nodes(Enum.reverse(t.children))
      }
    end
  end
end
