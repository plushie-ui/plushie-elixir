defmodule Julep.Test.EventMapTest do
  use ExUnit.Case, async: true

  alias Julep.Event.Canvas
  alias Julep.Event.MouseArea
  alias Julep.Event.Widget

  alias Julep.Test.Element
  alias Julep.Test.EventMap

  # -- Helpers --

  defp el(id, type, props \\ %{}) do
    %Element{id: id, type: type, props: props, children: []}
  end

  # -- click/1 --

  describe "click/1" do
    test "returns click event for button" do
      assert {:ok, %Widget{type: :click, id: "save"}} = EventMap.click(el("save", "button"))
    end

    test "returns error for non-clickable types" do
      for type <- ~w[text text_input slider checkbox column container] do
        assert {:error, msg} = EventMap.click(el("x", type))
        assert msg =~ "cannot click"
        assert msg =~ type
      end
    end
  end

  # -- input/2 --

  describe "input/2" do
    test "returns input event for text_input" do
      assert {:ok, %Widget{type: :input, id: "name", value: "Arthur"}} =
               EventMap.input(el("name", "text_input"), "Arthur")
    end

    test "returns input event for text_editor" do
      assert {:ok, %Widget{type: :input, id: "editor", value: "some text"}} =
               EventMap.input(el("editor", "text_editor"), "some text")
    end

    test "returns error for non-typeable widget" do
      assert {:error, msg} = EventMap.input(el("btn", "button"), "text")
      assert msg =~ "cannot type"
    end
  end

  # -- submit/1 --

  describe "submit/1" do
    test "returns submit event for text_input with value" do
      element = el("search", "text_input", %{"value" => "query"})

      assert {:ok, %Widget{type: :submit, id: "search", value: "query"}} =
               EventMap.submit(element)
    end

    test "returns submit event with empty string when no value" do
      element = el("search", "text_input")
      assert {:ok, %Widget{type: :submit, id: "search", value: ""}} = EventMap.submit(element)
    end

    test "returns error for non-submittable widget" do
      assert {:error, msg} = EventMap.submit(el("x", "button"))
      assert msg =~ "cannot submit"
    end
  end

  # -- toggle/1 --

  describe "toggle/1" do
    test "flips checkbox from unchecked to checked" do
      element = el("agree", "checkbox", %{"is_checked" => false})
      assert {:ok, %Widget{type: :toggle, id: "agree", value: true}} = EventMap.toggle(element)
    end

    test "flips checkbox from checked to unchecked" do
      element = el("agree", "checkbox", %{"is_checked" => true})
      assert {:ok, %Widget{type: :toggle, id: "agree", value: false}} = EventMap.toggle(element)
    end

    test "defaults unchecked when prop missing" do
      element = el("agree", "checkbox")
      assert {:ok, %Widget{type: :toggle, id: "agree", value: true}} = EventMap.toggle(element)
    end

    test "flips toggler from off to on" do
      element = el("dark_mode", "toggler", %{"is_toggled" => false})

      assert {:ok, %Widget{type: :toggle, id: "dark_mode", value: true}} =
               EventMap.toggle(element)
    end

    test "flips toggler from on to off" do
      element = el("dark_mode", "toggler", %{"is_toggled" => true})

      assert {:ok, %Widget{type: :toggle, id: "dark_mode", value: false}} =
               EventMap.toggle(element)
    end

    test "returns error for non-togglable widget" do
      assert {:error, msg} = EventMap.toggle(el("x", "text"))
      assert msg =~ "cannot toggle"
    end
  end

  # -- select/2 --

  describe "select/2" do
    test "returns select event for radio with group" do
      element = el("opt-a", "radio", %{"group" => "size"})

      assert {:ok, %Widget{type: :select, id: "size", value: "large"}} =
               EventMap.select(element, "large")
    end

    test "falls back to name prop for radio group" do
      element = el("opt-b", "radio", %{"name" => "colour"})

      assert {:ok, %Widget{type: :select, id: "colour", value: "red"}} =
               EventMap.select(element, "red")
    end

    test "returns select event for pick_list" do
      element = el("country", "pick_list")

      assert {:ok, %Widget{type: :select, id: "country", value: "NZ"}} =
               EventMap.select(element, "NZ")
    end

    test "returns select event for combo_box" do
      element = el("lang", "combo_box")

      assert {:ok, %Widget{type: :select, id: "lang", value: "Elixir"}} =
               EventMap.select(element, "Elixir")
    end

    test "returns error for non-selectable widget" do
      assert {:error, msg} = EventMap.select(el("x", "text"), "v")
      assert msg =~ "cannot select"
    end
  end

  # -- slide/2 --

  describe "slide/2" do
    test "returns slide event for slider" do
      assert {:ok, %Widget{type: :slide, id: "volume", value: 75}} =
               EventMap.slide(el("volume", "slider"), 75)
    end

    test "returns slide event for vertical_slider" do
      assert {:ok, %Widget{type: :slide, id: "pitch", value: 0.5}} =
               EventMap.slide(el("pitch", "vertical_slider"), 0.5)
    end

    test "returns error for non-slidable widget" do
      assert {:error, msg} = EventMap.slide(el("x", "button"), 42)
      assert msg =~ "cannot slide"
    end
  end

  # -- canvas_press/4 --

  describe "canvas_press/4" do
    test "returns canvas_press event with default button" do
      assert {:ok, %Canvas{type: :press, id: "drawing", x: 10.0, y: 20.0, button: "left"}} =
               EventMap.canvas_press(el("drawing", "canvas"), 10.0, 20.0)
    end

    test "returns canvas_press event with explicit button" do
      assert {:ok, %Canvas{type: :press, id: "drawing", x: 5.0, y: 15.0, button: "right"}} =
               EventMap.canvas_press(el("drawing", "canvas"), 5.0, 15.0, "right")
    end

    test "returns error for non-canvas widget" do
      assert {:error, msg} = EventMap.canvas_press(el("btn", "button"), 0, 0)
      assert msg =~ "cannot canvas_press"
    end
  end

  # -- canvas_release/4 --

  describe "canvas_release/4" do
    test "returns canvas_release event with default button" do
      assert {:ok, %Canvas{type: :release, id: "drawing", x: 10.0, y: 20.0, button: "left"}} =
               EventMap.canvas_release(el("drawing", "canvas"), 10.0, 20.0)
    end

    test "returns canvas_release event with explicit button" do
      assert {:ok, %Canvas{type: :release, id: "drawing", x: 5.0, y: 15.0, button: "middle"}} =
               EventMap.canvas_release(el("drawing", "canvas"), 5.0, 15.0, "middle")
    end

    test "returns error for non-canvas widget" do
      assert {:error, msg} = EventMap.canvas_release(el("x", "text"), 0, 0)
      assert msg =~ "cannot canvas_release"
    end
  end

  # -- canvas_move/3 --

  describe "canvas_move/3" do
    test "returns canvas_move event" do
      assert {:ok, %Canvas{type: :move, id: "drawing", x: 30.0, y: 40.0}} =
               EventMap.canvas_move(el("drawing", "canvas"), 30.0, 40.0)
    end

    test "returns error for non-canvas widget" do
      assert {:error, msg} = EventMap.canvas_move(el("x", "slider"), 0, 0)
      assert msg =~ "cannot canvas_move"
    end
  end

  # -- canvas_scroll/5 --

  describe "canvas_scroll/5" do
    test "returns canvas_scroll event with default deltas" do
      assert {:ok,
              %Canvas{type: :scroll, id: "drawing", x: 5.0, y: 5.0, delta_x: 0.0, delta_y: 1.0}} =
               EventMap.canvas_scroll(el("drawing", "canvas"), 5.0, 5.0)
    end

    test "returns canvas_scroll event with custom deltas" do
      assert {:ok,
              %Canvas{type: :scroll, id: "drawing", x: 5.0, y: 5.0, delta_x: 2.0, delta_y: -3.0}} =
               EventMap.canvas_scroll(el("drawing", "canvas"), 5.0, 5.0, 2.0, -3.0)
    end

    test "returns error for non-canvas widget" do
      assert {:error, msg} = EventMap.canvas_scroll(el("x", "button"), 0, 0)
      assert msg =~ "cannot canvas_scroll"
    end
  end

  # -- mouse_right_press/1 --

  describe "mouse_right_press/1" do
    test "returns event for mouse_area" do
      assert {:ok, %MouseArea{type: :right_press, id: "zone"}} =
               EventMap.mouse_right_press(el("zone", "mouse_area"))
    end

    test "returns error for non-mouse_area widget" do
      assert {:error, msg} = EventMap.mouse_right_press(el("x", "button"))
      assert msg =~ "cannot mouse_right_press"
    end
  end

  # -- mouse_right_release/1 --

  describe "mouse_right_release/1" do
    test "returns event for mouse_area" do
      assert {:ok, %MouseArea{type: :right_release, id: "zone"}} =
               EventMap.mouse_right_release(el("zone", "mouse_area"))
    end

    test "returns error for non-mouse_area widget" do
      assert {:error, msg} = EventMap.mouse_right_release(el("x", "text"))
      assert msg =~ "cannot mouse_right_release"
    end
  end

  # -- mouse_middle_release/1 --

  describe "mouse_middle_release/1" do
    test "returns event for mouse_area" do
      assert {:ok, %MouseArea{type: :middle_release, id: "zone"}} =
               EventMap.mouse_middle_release(el("zone", "mouse_area"))
    end

    test "returns error for non-mouse_area widget" do
      assert {:error, msg} = EventMap.mouse_middle_release(el("x", "text"))
      assert msg =~ "cannot mouse_middle_release"
    end
  end

  # -- mouse_double_click/1 --

  describe "mouse_double_click/1" do
    test "returns event for mouse_area" do
      assert {:ok, %MouseArea{type: :double_click, id: "zone"}} =
               EventMap.mouse_double_click(el("zone", "mouse_area"))
    end

    test "returns error for non-mouse_area widget" do
      assert {:error, msg} = EventMap.mouse_double_click(el("x", "button"))
      assert msg =~ "cannot mouse_double_click"
    end
  end

  # -- mouse_enter/1 --

  describe "mouse_enter/1" do
    test "returns event for mouse_area" do
      assert {:ok, %MouseArea{type: :enter, id: "zone"}} =
               EventMap.mouse_enter(el("zone", "mouse_area"))
    end

    test "returns error for non-mouse_area widget" do
      assert {:error, msg} = EventMap.mouse_enter(el("x", "text"))
      assert msg =~ "cannot mouse_enter"
    end
  end

  # -- mouse_exit/1 --

  describe "mouse_exit/1" do
    test "returns event for mouse_area" do
      assert {:ok, %MouseArea{type: :exit, id: "zone"}} =
               EventMap.mouse_exit(el("zone", "mouse_area"))
    end

    test "returns error for non-mouse_area widget" do
      assert {:error, msg} = EventMap.mouse_exit(el("x", "text"))
      assert msg =~ "cannot mouse_exit"
    end
  end

  # -- mouse_move/3 --

  describe "mouse_move/3" do
    test "returns event for mouse_area" do
      assert {:ok, %MouseArea{type: :move, id: "zone", x: 10.0, y: 20.0}} =
               EventMap.mouse_move(el("zone", "mouse_area"), 10.0, 20.0)
    end

    test "returns error for non-mouse_area widget" do
      assert {:error, msg} = EventMap.mouse_move(el("x", "button"), 0, 0)
      assert msg =~ "cannot mouse_move"
    end
  end

  # -- mouse_scroll/3 --

  describe "mouse_scroll/3" do
    test "returns event with default deltas" do
      assert {:ok, %MouseArea{type: :scroll, id: "zone", delta_x: delta_x, delta_y: delta_y}} =
               EventMap.mouse_scroll(el("zone", "mouse_area"))

      assert delta_x == +0.0
      assert delta_y == 1.0
    end

    test "returns event with custom deltas" do
      assert {:ok, %MouseArea{type: :scroll, id: "zone", delta_x: 2.0, delta_y: -3.0}} =
               EventMap.mouse_scroll(el("zone", "mouse_area"), 2.0, -3.0)
    end

    test "returns error for non-mouse_area widget" do
      assert {:error, msg} = EventMap.mouse_scroll(el("x", "button"), 0, 0)
      assert msg =~ "cannot mouse_scroll"
    end
  end
end
