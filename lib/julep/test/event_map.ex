defmodule Julep.Test.EventMap do
  @moduledoc """
  Maps widget types to the events they produce when interacted with.

  Used by the simulated backend to infer what event dispatching `click`,
  `type_text`, `toggle`, etc. should produce for a given widget type,
  without needing a real renderer.

  ## Event inference table

  All events are delivered as structs. `Widget` is `Julep.Event.Widget`,
  `MouseArea` is `Julep.Event.MouseArea`, `Canvas` is `Julep.Event.Canvas`.

  | Widget       | click                            | input                                    | submit                                   | toggle                                      | select                                        | slide                                    |
  |--------------|----------------------------------|------------------------------------------|------------------------------------------|---------------------------------------------|-----------------------------------------------|------------------------------------------|
  | button       | `%Widget{type: :click, id: id}`  | -                                        | -                                        | -                                           | -                                             | -                                        |
  | checkbox     | -                                | -                                        | -                                        | `%Widget{type: :toggle, id: id, value: v}`  | -                                             | -                                        |
  | toggler      | -                                | -                                        | -                                        | `%Widget{type: :toggle, id: id, value: v}`  | -                                             | -                                        |
  | radio        | -                                | -                                        | -                                        | -                                           | `%Widget{type: :select, id: group, value: v}` | -                                        |
  | text_input   | -                                | `%Widget{type: :input, id: id, value: v}`| `%Widget{type: :submit, id: id, value: v}`| -                                           | -                                             | -                                        |
  | text_editor  | -                                | `%Widget{type: :input, id: id, value: v}`| -                                        | -                                           | -                                             | -                                        |
  | slider       | -                                | -                                        | -                                        | -                                           | -                                             | `%Widget{type: :slide, id: id, value: v}`|
  | pick_list    | -                                | -                                        | -                                        | -                                           | `%Widget{type: :select, id: id, value: v}`    | -                                        |
  | combo_box    | -                                | -                                        | -                                        | -                                           | `%Widget{type: :select, id: id, value: v}`    | -                                        |

  MouseArea widgets use dedicated event producers for conditional events:

  | Producer              | Event                                                                  |
  |-----------------------|------------------------------------------------------------------------|
  | `mouse_right_press`   | `%MouseArea{type: :right_press, id: id}`                               |
  | `mouse_right_release` | `%MouseArea{type: :right_release, id: id}`                             |
  | `mouse_middle_press`  | `%MouseArea{type: :middle_press, id: id}`                              |
  | `mouse_middle_release`| `%MouseArea{type: :middle_release, id: id}`                            |
  | `mouse_double_click`  | `%MouseArea{type: :double_click, id: id}`                              |
  | `mouse_enter`         | `%MouseArea{type: :enter, id: id}`                                     |
  | `mouse_exit`          | `%MouseArea{type: :exit, id: id}`                                      |
  | `mouse_move`          | `%MouseArea{type: :move, id: id, x: x, y: y}`                         |
  | `mouse_scroll`        | `%MouseArea{type: :scroll, id: id, delta_x: dx, delta_y: dy}`         |

  Canvas widgets use dedicated event producers instead of the generic verbs above:

  | Producer         | Event                                                            |
  |------------------|------------------------------------------------------------------|
  | `canvas_press`   | `%Canvas{type: :press, id: id, x: x, y: y, button: b}`         |
  | `canvas_release` | `%Canvas{type: :release, id: id, x: x, y: y, button: b}`       |
  | `canvas_move`    | `%Canvas{type: :move, id: id, x: x, y: y}`                      |
  | `canvas_scroll`  | `%Canvas{type: :scroll, id: id, x: x, y: y, delta_x: dx, delta_y: dy}` |
  """

  alias Julep.Event.Canvas, as: CanvasEvent
  alias Julep.Event.MouseArea, as: MouseAreaEvent
  alias Julep.Event.Widget, as: WidgetEvent
  alias Julep.Test.Element

  @doc "Infers the event produced by clicking a widget."
  @spec click(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def click(%Element{type: "button", id: id}), do: {:ok, %WidgetEvent{type: :click, id: id}}

  def click(%Element{type: type}) when type in ~w(checkbox toggler),
    do: {:error, "cannot click a #{type} widget -- use toggle/1 instead"}

  def click(%Element{type: type} = el) do
    case Julep.Test.ExtensionEvents.dispatch(:click, el, []) do
      :not_handled -> {:error, "cannot click a #{type} widget"}
      result -> result
    end
  end

  @doc "Infers the event produced by typing text into a widget."
  @spec input(element :: Element.t(), text :: String.t()) :: {:ok, struct()} | {:error, String.t()}
  def input(%Element{type: "text_input", id: id}, text), do: {:ok, %WidgetEvent{type: :input, id: id, value: text}}
  def input(%Element{type: "text_editor", id: id}, text), do: {:ok, %WidgetEvent{type: :input, id: id, value: text}}

  def input(%Element{type: type} = el, text) do
    case Julep.Test.ExtensionEvents.dispatch(:input, el, [text]) do
      :not_handled -> {:error, "cannot type into a #{type} widget"}
      result -> result
    end
  end

  @doc "Infers the event produced by submitting a widget."
  @spec submit(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def submit(%Element{type: "text_input", id: id, props: props}) do
    {:ok, %WidgetEvent{type: :submit, id: id, value: props["value"] || ""}}
  end

  def submit(%Element{type: type} = el) do
    case Julep.Test.ExtensionEvents.dispatch(:submit, el, []) do
      :not_handled -> {:error, "cannot submit a #{type} widget"}
      result -> result
    end
  end

  @doc "Infers the event produced by toggling a widget."
  @spec toggle(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def toggle(%Element{type: "checkbox", id: id, props: props}) do
    current = props["is_checked"] || false
    {:ok, %WidgetEvent{type: :toggle, id: id, value: !current}}
  end

  def toggle(%Element{type: "toggler", id: id, props: props}) do
    current = props["is_toggled"] || false
    {:ok, %WidgetEvent{type: :toggle, id: id, value: !current}}
  end

  def toggle(%Element{type: type}) when type in ~w(button),
    do: {:error, "cannot toggle a #{type} widget -- use click/1 instead"}

  def toggle(%Element{type: type} = el) do
    case Julep.Test.ExtensionEvents.dispatch(:toggle, el, []) do
      :not_handled -> {:error, "cannot toggle a #{type} widget"}
      result -> result
    end
  end

  @doc "Infers the event produced by selecting a value from a widget."
  @spec select(element :: Element.t(), value :: term()) :: {:ok, struct()} | {:error, String.t()}
  def select(%Element{type: "radio", props: props}, value) do
    group = props["group"] || props["name"]
    {:ok, %WidgetEvent{type: :select, id: group, value: value}}
  end

  def select(%Element{type: "pick_list", id: id}, value), do: {:ok, %WidgetEvent{type: :select, id: id, value: value}}
  def select(%Element{type: "combo_box", id: id}, value), do: {:ok, %WidgetEvent{type: :select, id: id, value: value}}

  def select(%Element{type: type} = el, value) do
    case Julep.Test.ExtensionEvents.dispatch(:select, el, [value]) do
      :not_handled -> {:error, "cannot select from a #{type} widget"}
      result -> result
    end
  end

  @doc "Infers the event produced by sliding a widget to a value."
  @spec slide(element :: Element.t(), value :: number()) :: {:ok, struct()} | {:error, String.t()}
  def slide(%Element{type: "slider", id: id}, value), do: {:ok, %WidgetEvent{type: :slide, id: id, value: value}}
  def slide(%Element{type: "vertical_slider", id: id}, value), do: {:ok, %WidgetEvent{type: :slide, id: id, value: value}}

  def slide(%Element{type: type} = el, value) do
    case Julep.Test.ExtensionEvents.dispatch(:slide, el, [value]) do
      :not_handled -> {:error, "cannot slide a #{type} widget"}
      result -> result
    end
  end

  # -- Open/Close events --

  @doc "Produces an open event for a pick_list widget."
  @spec pick_list_open(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def pick_list_open(%Element{type: "pick_list", id: id}), do: {:ok, %WidgetEvent{type: :open, id: id}}

  def pick_list_open(%Element{type: type}),
    do: {:error, "cannot produce open event for a #{type} widget"}

  @doc "Produces a close event for a pick_list widget."
  @spec pick_list_close(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def pick_list_close(%Element{type: "pick_list", id: id}), do: {:ok, %WidgetEvent{type: :close, id: id}}

  def pick_list_close(%Element{type: type}),
    do: {:error, "cannot produce close event for a #{type} widget"}

  @doc "Produces an open event for a combo_box widget."
  @spec combo_box_open(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def combo_box_open(%Element{type: "combo_box", id: id}), do: {:ok, %WidgetEvent{type: :open, id: id}}

  def combo_box_open(%Element{type: type}),
    do: {:error, "cannot produce open event for a #{type} widget"}

  @doc "Produces a close event for a combo_box widget."
  @spec combo_box_close(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def combo_box_close(%Element{type: "combo_box", id: id}), do: {:ok, %WidgetEvent{type: :close, id: id}}

  def combo_box_close(%Element{type: type}),
    do: {:error, "cannot produce close event for a #{type} widget"}

  # -- Canvas events --

  @doc "Produces a canvas press event at the given coordinates."
  @spec canvas_press(element :: Element.t(), x :: number(), y :: number(), button :: String.t()) ::
          {:ok, struct()} | {:error, String.t()}
  def canvas_press(element, x, y, button \\ "left")

  def canvas_press(%Element{type: "canvas", id: id}, x, y, button) do
    {:ok, %CanvasEvent{type: :press, id: id, x: x, y: y, button: button}}
  end

  def canvas_press(%Element{type: type}, _x, _y, _button),
    do: {:error, "cannot canvas_press a #{type} widget"}

  @doc "Produces a canvas release event at the given coordinates."
  @spec canvas_release(element :: Element.t(), x :: number(), y :: number(), button :: String.t()) ::
          {:ok, struct()} | {:error, String.t()}
  def canvas_release(element, x, y, button \\ "left")

  def canvas_release(%Element{type: "canvas", id: id}, x, y, button) do
    {:ok, %CanvasEvent{type: :release, id: id, x: x, y: y, button: button}}
  end

  def canvas_release(%Element{type: type}, _x, _y, _button),
    do: {:error, "cannot canvas_release a #{type} widget"}

  @doc "Produces a canvas cursor move event at the given coordinates."
  @spec canvas_move(element :: Element.t(), x :: number(), y :: number()) ::
          {:ok, struct()} | {:error, String.t()}
  def canvas_move(%Element{type: "canvas", id: id}, x, y) do
    {:ok, %CanvasEvent{type: :move, id: id, x: x, y: y}}
  end

  def canvas_move(%Element{type: type}, _x, _y),
    do: {:error, "cannot canvas_move a #{type} widget"}

  @doc "Produces a canvas scroll event at the given coordinates with scroll deltas."
  @spec canvas_scroll(
          element :: Element.t(),
          x :: number(),
          y :: number(),
          delta_x :: number(),
          delta_y :: number()
        ) :: {:ok, struct()} | {:error, String.t()}
  def canvas_scroll(element, x, y, delta_x \\ 0.0, delta_y \\ 1.0)

  def canvas_scroll(%Element{type: "canvas", id: id}, x, y, delta_x, delta_y) do
    {:ok, %CanvasEvent{type: :scroll, id: id, x: x, y: y, delta_x: delta_x, delta_y: delta_y}}
  end

  def canvas_scroll(%Element{type: type}, _x, _y, _delta_x, _delta_y),
    do: {:error, "cannot canvas_scroll a #{type} widget"}

  # -- MouseArea events --

  @doc "Produces a mouse right-press event for a mouse_area widget."
  @spec mouse_right_press(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def mouse_right_press(%Element{type: "mouse_area", id: id}),
    do: {:ok, %MouseAreaEvent{type: :right_press, id: id}}

  def mouse_right_press(%Element{type: type}),
    do: {:error, "cannot mouse_right_press a #{type} widget"}

  @doc "Produces a mouse right-release event for a mouse_area widget."
  @spec mouse_right_release(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def mouse_right_release(%Element{type: "mouse_area", id: id}),
    do: {:ok, %MouseAreaEvent{type: :right_release, id: id}}

  def mouse_right_release(%Element{type: type}),
    do: {:error, "cannot mouse_right_release a #{type} widget"}

  @doc "Produces a mouse middle-press event for a mouse_area widget."
  @spec mouse_middle_press(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def mouse_middle_press(%Element{type: "mouse_area", id: id}),
    do: {:ok, %MouseAreaEvent{type: :middle_press, id: id}}

  def mouse_middle_press(%Element{type: type}),
    do: {:error, "cannot mouse_middle_press a #{type} widget"}

  @doc "Produces a mouse middle-release event for a mouse_area widget."
  @spec mouse_middle_release(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def mouse_middle_release(%Element{type: "mouse_area", id: id}),
    do: {:ok, %MouseAreaEvent{type: :middle_release, id: id}}

  def mouse_middle_release(%Element{type: type}),
    do: {:error, "cannot mouse_middle_release a #{type} widget"}

  @doc "Produces a mouse double-click event for a mouse_area widget."
  @spec mouse_double_click(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def mouse_double_click(%Element{type: "mouse_area", id: id}),
    do: {:ok, %MouseAreaEvent{type: :double_click, id: id}}

  def mouse_double_click(%Element{type: type}),
    do: {:error, "cannot mouse_double_click a #{type} widget"}

  @doc "Produces a mouse enter event for a mouse_area widget."
  @spec mouse_enter(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def mouse_enter(%Element{type: "mouse_area", id: id}), do: {:ok, %MouseAreaEvent{type: :enter, id: id}}

  def mouse_enter(%Element{type: type}),
    do: {:error, "cannot mouse_enter a #{type} widget"}

  @doc "Produces a mouse exit event for a mouse_area widget."
  @spec mouse_exit(element :: Element.t()) :: {:ok, struct()} | {:error, String.t()}
  def mouse_exit(%Element{type: "mouse_area", id: id}), do: {:ok, %MouseAreaEvent{type: :exit, id: id}}

  def mouse_exit(%Element{type: type}),
    do: {:error, "cannot mouse_exit a #{type} widget"}

  @doc "Produces a mouse move event for a mouse_area widget at the given coordinates."
  @spec mouse_move(element :: Element.t(), x :: number(), y :: number()) ::
          {:ok, struct()} | {:error, String.t()}
  def mouse_move(%Element{type: "mouse_area", id: id}, x, y),
    do: {:ok, %MouseAreaEvent{type: :move, id: id, x: x, y: y}}

  def mouse_move(%Element{type: type}, _x, _y),
    do: {:error, "cannot mouse_move a #{type} widget"}

  @doc "Produces a mouse scroll event for a mouse_area widget with scroll deltas."
  @spec mouse_scroll(
          element :: Element.t(),
          delta_x :: number(),
          delta_y :: number()
        ) :: {:ok, struct()} | {:error, String.t()}
  def mouse_scroll(element, delta_x \\ 0.0, delta_y \\ 1.0)

  def mouse_scroll(%Element{type: "mouse_area", id: id}, delta_x, delta_y),
    do: {:ok, %MouseAreaEvent{type: :scroll, id: id, delta_x: delta_x, delta_y: delta_y}}

  def mouse_scroll(%Element{type: type}, _delta_x, _delta_y),
    do: {:error, "cannot mouse_scroll a #{type} widget"}

  # -- TextEditor key_binding events --

  @doc "Produces a key_binding event for a text_editor widget."
  @spec text_editor_key_binding(element :: Element.t(), tag :: String.t()) ::
          {:ok, struct()} | {:error, String.t()}
  def text_editor_key_binding(%Element{type: "text_editor", id: id}, tag),
    do: {:ok, %WidgetEvent{type: :key_binding, id: id, value: tag}}

  def text_editor_key_binding(%Element{type: type}, _tag),
    do: {:error, "cannot produce key_binding event for a #{type} widget"}

  # -- Table events --

  @doc "Produces a table sort event for the given column key."
  @spec table_sort(element :: Element.t(), column :: String.t()) ::
          {:ok, struct()} | {:error, String.t()}
  def table_sort(%Element{type: "table", id: id}, column) do
    {:ok, %WidgetEvent{type: :sort, id: id, value: column}}
  end

  def table_sort(%Element{type: type}, _column),
    do: {:error, "cannot table_sort a #{type} widget"}
end
