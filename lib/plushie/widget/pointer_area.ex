defmodule Plushie.Widget.PointerArea do
  @moduledoc """
  Pointer area, captures mouse events on child content.

  Wraps child content and emits click events for various mouse buttons,
  hover enter/exit, cursor movement, scroll, and double-click events.
  Optionally sets the mouse cursor when hovering the area.
  """

  use Plushie.Widget

  widget :pointer_area, container: :single do
    field :cursor, :atom, doc: "Mouse cursor to show on hover (e.g. `:pointer`, `:grab`)."
    field :on_press, :string, doc: "Event tag for left mouse press events."
    field :on_release, :string, doc: "Event tag for left mouse release events."
    field :on_right_press, :boolean, doc: "Enable right mouse press events."
    field :on_right_release, :boolean, doc: "Enable right mouse release events."
    field :on_middle_press, :boolean, doc: "Enable middle mouse press events."
    field :on_middle_release, :boolean, doc: "Enable middle mouse release events."
    field :on_double_click, :boolean, doc: "Enable double-click events."
    field :on_enter, :boolean, doc: "Enable cursor enter events."
    field :on_exit, :boolean, doc: "Enable cursor exit events."
    field :on_move, :boolean, doc: "Enable cursor move events."
    field :on_scroll, :boolean, doc: "Enable scroll wheel events."
  end
end
