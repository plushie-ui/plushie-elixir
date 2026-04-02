defmodule Plushie.Widget.PointerAreaTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.PointerArea

  describe "new/2" do
    test "creates a mouse area with no cursor by default" do
      ma = PointerArea.new("click_zone")

      assert ma.id == "click_zone"
      assert ma.cursor == nil
      assert ma.children == []
    end

    test "accepts a cursor option" do
      ma = PointerArea.new("link", cursor: :pointer)

      assert ma.cursor == :pointer
    end
  end

  describe "cursor/2" do
    test "sets the cursor" do
      ma = PointerArea.new("ma1") |> PointerArea.cursor(:grab)
      assert ma.cursor == :grab
    end

    test "overwrites a previously set cursor" do
      ma =
        PointerArea.new("ma1")
        |> PointerArea.cursor(:pointer)
        |> PointerArea.cursor(:crosshair)

      assert ma.cursor == :crosshair
    end
  end

  describe "push/2 and extend/2" do
    test "push appends a child node" do
      child = %{id: "inner", type: "text", props: %{content: "hi"}, children: []}
      ma = PointerArea.new("ma1") |> PointerArea.push(child)

      assert length(ma.children) == 1
      assert hd(ma.children) == child
    end

    test "extend appends multiple children" do
      c1 = %{id: "a", type: "text", props: %{}, children: []}
      c2 = %{id: "b", type: "text", props: %{}, children: []}
      ma = PointerArea.new("ma1") |> PointerArea.extend([c1, c2])

      assert length(ma.children) == 2
    end
  end

  describe "build/1" do
    test "includes cursor in props when set" do
      node = PointerArea.new("ma1") |> PointerArea.cursor(:pointer) |> PointerArea.build()

      assert node.id == "ma1"
      assert node.type == "pointer_area"
      assert node.props[:cursor] == :pointer
    end

    test "omits cursor from props when nil" do
      node = PointerArea.new("ma1") |> PointerArea.build()

      refute Map.has_key?(node.props, "cursor")
    end

    test "converts children through the Widget protocol" do
      child = %{id: "child", type: "text", props: %{content: "hello"}, children: []}
      node = PointerArea.new("ma1") |> PointerArea.push(child) |> PointerArea.build()

      assert length(node.children) == 1
      assert hd(node.children).id == "child"
    end
  end

  describe "event prop builders" do
    test "on_right_press/2 sets the field" do
      ma = PointerArea.new("ma1") |> PointerArea.on_right_press(true)
      assert ma.on_right_press == true
    end

    test "on_right_release/2 sets the field" do
      ma = PointerArea.new("ma1") |> PointerArea.on_right_release(true)
      assert ma.on_right_release == true
    end

    test "on_middle_press/2 sets the field" do
      ma = PointerArea.new("ma1") |> PointerArea.on_middle_press(true)
      assert ma.on_middle_press == true
    end

    test "on_middle_release/2 sets the field" do
      ma = PointerArea.new("ma1") |> PointerArea.on_middle_release(true)
      assert ma.on_middle_release == true
    end

    test "on_double_click/2 sets the field" do
      ma = PointerArea.new("ma1") |> PointerArea.on_double_click(true)
      assert ma.on_double_click == true
    end

    test "on_enter/2 sets the field" do
      ma = PointerArea.new("ma1") |> PointerArea.on_enter(true)
      assert ma.on_enter == true
    end

    test "on_exit/2 sets the field" do
      ma = PointerArea.new("ma1") |> PointerArea.on_exit(true)
      assert ma.on_exit == true
    end

    test "on_move/2 sets the field" do
      ma = PointerArea.new("ma1") |> PointerArea.on_move(true)
      assert ma.on_move == true
    end

    test "on_scroll/2 sets the field" do
      ma = PointerArea.new("ma1") |> PointerArea.on_scroll(true)
      assert ma.on_scroll == true
    end
  end

  describe "build/1 event props" do
    test "includes event props when set to true" do
      node =
        PointerArea.new("ma1")
        |> PointerArea.on_right_press(true)
        |> PointerArea.on_move(true)
        |> PointerArea.on_scroll(true)
        |> PointerArea.build()

      assert node.props[:on_right_press] == true
      assert node.props[:on_move] == true
      assert node.props[:on_scroll] == true
    end

    test "omits event props when nil" do
      node = PointerArea.new("ma1") |> PointerArea.build()

      for key <- ~w(on_right_press on_right_release on_middle_press on_middle_release
                     on_double_click on_enter on_exit on_move on_scroll) do
        refute Map.has_key?(node.props, key)
      end
    end
  end

  describe "with_options/2" do
    test "accepts all event options" do
      ma =
        PointerArea.new("ma1",
          on_right_press: true,
          on_right_release: true,
          on_middle_press: true,
          on_middle_release: true,
          on_double_click: true,
          on_enter: true,
          on_exit: true,
          on_move: true,
          on_scroll: true
        )

      assert ma.on_right_press == true
      assert ma.on_right_release == true
      assert ma.on_middle_press == true
      assert ma.on_middle_release == true
      assert ma.on_double_click == true
      assert ma.on_enter == true
      assert ma.on_exit == true
      assert ma.on_move == true
      assert ma.on_scroll == true
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, fn ->
        PointerArea.new("ma1", style: :fancy)
      end
    end
  end
end
