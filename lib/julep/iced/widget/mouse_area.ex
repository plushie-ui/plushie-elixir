defmodule Julep.Iced.Widget.MouseArea do
  @moduledoc """
  Mouse area -- captures mouse events on child content.

  Wraps child content and emits click events for various mouse buttons.
  Optionally sets the mouse cursor when hovering the area.

  ## Props

  - `cursor` (atom) -- mouse cursor to show on hover. One of: `:pointer`,
    `:grab`, `:grabbing`, `:crosshair`, `:text`, `:move`, `:not_allowed`,
    `:progress`, `:wait`, `:help`, `:cell`, `:copy`, `:alias`, `:no_drop`,
    `:all_scroll`, `:zoom_in`, `:zoom_out`, `:context_menu`,
    `:resizing_horizontally`, `:resizing_vertically`,
    `:resizing_diagonally_up`, `:resizing_diagonally_down`,
    `:resizing_column`, `:resizing_row`.

  ## Events

  - `{:click, id}` -- left mouse button pressed.
  - `{:click, "id:release"}` -- left mouse button released.
  - `{:click, "id:middle"}` -- middle mouse button pressed.
  """

  alias Julep.Iced.Widget.Build

  @type cursor ::
          :pointer
          | :grab
          | :grabbing
          | :crosshair
          | :text
          | :move
          | :not_allowed
          | :progress
          | :wait
          | :help
          | :cell
          | :copy
          | :alias
          | :no_drop
          | :all_scroll
          | :zoom_in
          | :zoom_out
          | :context_menu
          | :resizing_horizontally
          | :resizing_vertically
          | :resizing_diagonally_up
          | :resizing_diagonally_down
          | :resizing_column
          | :resizing_row

  @type option :: {:cursor, cursor()}

  @type t :: %__MODULE__{
          id: String.t(),
          cursor: cursor() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [:id, :cursor, children: []]

  @doc "Creates a new mouse area struct."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id), do: %__MODULE__{id: id} |> with_options(opts)

  @doc "Applies keyword options to an existing mouse area struct."
  @spec with_options(mouse_area :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = ma, []), do: ma

  def with_options(%__MODULE__{} = ma, opts) do
    Enum.reduce(opts, ma, fn
      {:cursor, v}, acc -> cursor(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the mouse cursor shown on hover."
  @spec cursor(mouse_area :: t(), cursor :: cursor()) :: t()
  def cursor(%__MODULE__{} = ma, cursor), do: %{ma | cursor: cursor}

  @doc "Appends a child to the mouse area."
  @spec push(mouse_area :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = ma, child), do: %{ma | children: ma.children ++ [child]}

  @doc "Appends multiple children to the mouse area."
  @spec extend(mouse_area :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = ma, children), do: %{ma | children: ma.children ++ children}

  @doc "Converts this mouse area struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(mouse_area :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = ma), do: Julep.Iced.Widget.to_node(ma)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(ma) do
      props =
        %{}
        |> put_if(ma.cursor, "cursor")

      %{id: ma.id, type: "mouse_area", props: props, children: children_to_nodes(ma.children)}
    end
  end
end
