defmodule Julep.Iced.Widget.MouseArea do
  @moduledoc """
  Mouse area -- captures mouse events on child content.

  Wraps child content and emits click events for various mouse buttons,
  hover enter/exit, cursor movement, scroll, and double-click events.
  Optionally sets the mouse cursor when hovering the area.

  ## Props

  - `cursor` (atom) -- mouse cursor to show on hover. One of: `:pointer`,
    `:grab`, `:grabbing`, `:crosshair`, `:text`, `:move`, `:not_allowed`,
    `:progress`, `:wait`, `:help`, `:cell`, `:copy`, `:alias`, `:no_drop`,
    `:all_scroll`, `:zoom_in`, `:zoom_out`, `:context_menu`,
    `:resizing_horizontally`, `:resizing_vertically`,
    `:resizing_diagonally_up`, `:resizing_diagonally_down`,
    `:resizing_column`, `:resizing_row`.
  - `on_right_press` (boolean) -- enable right mouse button press events.
  - `on_right_release` (boolean) -- enable right mouse button release events.
  - `on_middle_press` (boolean) -- enable middle mouse button press events.
  - `on_middle_release` (boolean) -- enable middle mouse button release events.
  - `on_double_click` (boolean) -- enable double-click events.
  - `on_enter` (boolean) -- enable cursor enter events.
  - `on_exit` (boolean) -- enable cursor exit events.
  - `on_move` (boolean) -- enable cursor move events.
  - `on_scroll` (boolean) -- enable scroll wheel events.

  ## Events

  Always emitted (unconditional):

  - `%Widget{type: :click, id: id}` -- left mouse button pressed.
  - `%Widget{type: :click, id: "id:release"}` -- left mouse button released.

  Conditional (opt-in via props, delivered as `%MouseArea{}` structs):

  - `%MouseArea{type: :middle_press, id: id}` -- middle mouse button pressed.
  - `%MouseArea{type: :right_press, id: id}` -- right mouse button pressed.
  - `%MouseArea{type: :right_release, id: id}` -- right mouse button released.
  - `%MouseArea{type: :middle_release, id: id}` -- middle mouse button released.
  - `%MouseArea{type: :double_click, id: id}` -- left mouse button double-clicked.
  - `%MouseArea{type: :enter, id: id}` -- cursor entered the area.
  - `%MouseArea{type: :exit, id: id}` -- cursor exited the area.
  - `%MouseArea{type: :move, id: id, x: x, y: y}` -- cursor moved within the area.
  - `%MouseArea{type: :scroll, id: id, delta_x: dx, delta_y: dy}` -- scroll wheel within the area.
  """

  alias Julep.Iced.A11y
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

  @type option ::
          {:cursor, cursor()}
          | {:on_right_press, boolean()}
          | {:on_right_release, boolean()}
          | {:on_middle_press, boolean()}
          | {:on_middle_release, boolean()}
          | {:on_double_click, boolean()}
          | {:on_enter, boolean()}
          | {:on_exit, boolean()}
          | {:on_move, boolean()}
          | {:on_scroll, boolean()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          cursor: cursor() | nil,
          on_right_press: boolean() | nil,
          on_right_release: boolean() | nil,
          on_middle_press: boolean() | nil,
          on_middle_release: boolean() | nil,
          on_double_click: boolean() | nil,
          on_enter: boolean() | nil,
          on_exit: boolean() | nil,
          on_move: boolean() | nil,
          on_scroll: boolean() | nil,
          a11y: Julep.Iced.A11y.t() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :cursor,
    :on_right_press,
    :on_right_release,
    :on_middle_press,
    :on_middle_release,
    :on_double_click,
    :on_enter,
    :on_exit,
    :on_move,
    :on_scroll,
    :a11y,
    children: []
  ]

  @doc "Creates a new mouse area struct."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id), do: %__MODULE__{id: id} |> with_options(opts)

  @doc "Applies keyword options to an existing mouse area struct."
  @spec with_options(mouse_area :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = ma, []), do: ma

  def with_options(%__MODULE__{} = ma, opts) do
    Enum.reduce(opts, ma, fn
      {:cursor, v}, acc -> cursor(acc, v)
      {:on_right_press, v}, acc -> on_right_press(acc, v)
      {:on_right_release, v}, acc -> on_right_release(acc, v)
      {:on_middle_press, v}, acc -> on_middle_press(acc, v)
      {:on_middle_release, v}, acc -> on_middle_release(acc, v)
      {:on_double_click, v}, acc -> on_double_click(acc, v)
      {:on_enter, v}, acc -> on_enter(acc, v)
      {:on_exit, v}, acc -> on_exit(acc, v)
      {:on_move, v}, acc -> on_move(acc, v)
      {:on_scroll, v}, acc -> on_scroll(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the mouse cursor shown on hover."
  @spec cursor(mouse_area :: t(), cursor :: cursor()) :: t()
  def cursor(%__MODULE__{} = ma, cursor), do: %{ma | cursor: cursor}

  @doc "Enables or disables right mouse button press events."
  @spec on_right_press(mouse_area :: t(), enabled :: boolean()) :: t()
  def on_right_press(%__MODULE__{} = ma, enabled), do: %{ma | on_right_press: enabled}

  @doc "Enables or disables right mouse button release events."
  @spec on_right_release(mouse_area :: t(), enabled :: boolean()) :: t()
  def on_right_release(%__MODULE__{} = ma, enabled), do: %{ma | on_right_release: enabled}

  @doc "Enables or disables middle mouse button press events."
  @spec on_middle_press(mouse_area :: t(), enabled :: boolean()) :: t()
  def on_middle_press(%__MODULE__{} = ma, enabled), do: %{ma | on_middle_press: enabled}

  @doc "Enables or disables middle mouse button release events."
  @spec on_middle_release(mouse_area :: t(), enabled :: boolean()) :: t()
  def on_middle_release(%__MODULE__{} = ma, enabled), do: %{ma | on_middle_release: enabled}

  @doc "Enables or disables double-click events."
  @spec on_double_click(mouse_area :: t(), enabled :: boolean()) :: t()
  def on_double_click(%__MODULE__{} = ma, enabled), do: %{ma | on_double_click: enabled}

  @doc "Enables or disables cursor enter events."
  @spec on_enter(mouse_area :: t(), enabled :: boolean()) :: t()
  def on_enter(%__MODULE__{} = ma, enabled), do: %{ma | on_enter: enabled}

  @doc "Enables or disables cursor exit events."
  @spec on_exit(mouse_area :: t(), enabled :: boolean()) :: t()
  def on_exit(%__MODULE__{} = ma, enabled), do: %{ma | on_exit: enabled}

  @doc "Enables or disables cursor move events."
  @spec on_move(mouse_area :: t(), enabled :: boolean()) :: t()
  def on_move(%__MODULE__{} = ma, enabled), do: %{ma | on_move: enabled}

  @doc "Enables or disables scroll wheel events."
  @spec on_scroll(mouse_area :: t(), enabled :: boolean()) :: t()
  def on_scroll(%__MODULE__{} = ma, enabled), do: %{ma | on_scroll: enabled}

  @doc "Appends a child to the mouse area."
  @spec push(mouse_area :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = ma, child), do: %{ma | children: [child | ma.children]}

  @doc "Appends multiple children to the mouse area."
  @spec extend(mouse_area :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = ma, children),
    do: %{ma | children: Enum.reverse(children) ++ ma.children}

  @doc "Sets accessibility annotations."
  @spec a11y(mouse_area :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = ma, a11y), do: %{ma | a11y: A11y.cast(a11y)}

  @doc "Converts this mouse area struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(mouse_area :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = ma), do: Julep.Iced.Widget.to_node(ma)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(ma) do
      props =
        %{}
        |> put_if(ma.cursor, "cursor")
        |> put_if(ma.on_right_press, "on_right_press")
        |> put_if(ma.on_right_release, "on_right_release")
        |> put_if(ma.on_middle_press, "on_middle_press")
        |> put_if(ma.on_middle_release, "on_middle_release")
        |> put_if(ma.on_double_click, "on_double_click")
        |> put_if(ma.on_enter, "on_enter")
        |> put_if(ma.on_exit, "on_exit")
        |> put_if(ma.on_move, "on_move")
        |> put_if(ma.on_scroll, "on_scroll")
        |> put_if(ma.a11y, "a11y")

      %{
        id: ma.id,
        type: "mouse_area",
        props: props,
        children: children_to_nodes(Enum.reverse(ma.children))
      }
    end
  end
end
