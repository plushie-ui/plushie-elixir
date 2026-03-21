defmodule Plushie.Widget.Themer do
  @moduledoc """
  Per-subtree theme override -- applies a different theme to child widgets.

  ## Props

  - `theme` -- a built-in theme atom (e.g. `:dark`, `:nord`) or a custom
    palette map. See `Plushie.Type.Theme`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  alias Plushie.Type.A11y
  alias Plushie.Widget.Build

  @type option ::
          {:theme, Plushie.Type.Theme.t()}
          | {:a11y, Plushie.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          theme: Plushie.Type.Theme.t(),
          a11y: Plushie.Type.A11y.t() | nil,
          children: [Plushie.Widget.ui_node() | struct()]
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
    %{a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new themer struct with the given theme."
  @spec new(id :: String.t(), theme_or_opts :: Plushie.Type.Theme.t() | [option()]) :: t()
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
  @spec push(themer :: t(), child :: Plushie.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = t, child), do: %{t | children: [child | t.children]}

  @doc "Appends multiple children to the themer."
  @spec extend(themer :: t(), children :: [Plushie.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = t, children),
    do: %{t | children: Enum.reverse(children) ++ t.children}

  @doc "Sets accessibility annotations."
  @spec a11y(themer :: t(), a11y :: Plushie.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = t, a11y), do: %{t | a11y: A11y.cast(a11y)}

  @doc "Converts this themer struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(themer :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = t), do: Plushie.Widget.to_node(t)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

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
