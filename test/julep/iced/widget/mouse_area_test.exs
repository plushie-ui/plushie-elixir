defmodule Julep.Iced.Widget.MouseAreaTest do
  use ExUnit.Case, async: true

  alias Julep.Iced.Widget.MouseArea

  # ---------------------------------------------------------------------------
  # Construction
  # ---------------------------------------------------------------------------

  describe "new/2" do
    test "creates a mouse area with no cursor by default" do
      ma = MouseArea.new("click_zone")

      assert ma.id == "click_zone"
      assert ma.cursor == nil
      assert ma.children == []
    end

    test "accepts a cursor option" do
      ma = MouseArea.new("link", cursor: :pointer)

      assert ma.cursor == :pointer
    end
  end

  # ---------------------------------------------------------------------------
  # Builders
  # ---------------------------------------------------------------------------

  describe "cursor/2" do
    test "sets the cursor" do
      ma = MouseArea.new("ma1") |> MouseArea.cursor(:grab)
      assert ma.cursor == :grab
    end

    test "overwrites a previously set cursor" do
      ma =
        MouseArea.new("ma1")
        |> MouseArea.cursor(:pointer)
        |> MouseArea.cursor(:crosshair)

      assert ma.cursor == :crosshair
    end
  end

  describe "push/2 and extend/2" do
    test "push appends a child node" do
      child = %{id: "inner", type: "text", props: %{"content" => "hi"}, children: []}
      ma = MouseArea.new("ma1") |> MouseArea.push(child)

      assert length(ma.children) == 1
      assert hd(ma.children) == child
    end

    test "extend appends multiple children" do
      c1 = %{id: "a", type: "text", props: %{}, children: []}
      c2 = %{id: "b", type: "text", props: %{}, children: []}
      ma = MouseArea.new("ma1") |> MouseArea.extend([c1, c2])

      assert length(ma.children) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # build/1 -- node output
  # ---------------------------------------------------------------------------

  describe "build/1" do
    test "includes cursor in props when set" do
      node = MouseArea.new("ma1") |> MouseArea.cursor(:pointer) |> MouseArea.build()

      assert node.id == "ma1"
      assert node.type == "mouse_area"
      assert node.props["cursor"] == "pointer"
    end

    test "omits cursor from props when nil" do
      node = MouseArea.new("ma1") |> MouseArea.build()

      refute Map.has_key?(node.props, "cursor")
    end

    test "converts children through the Widget protocol" do
      child = %{id: "child", type: "text", props: %{"content" => "hello"}, children: []}
      node = MouseArea.new("ma1") |> MouseArea.push(child) |> MouseArea.build()

      assert length(node.children) == 1
      assert hd(node.children).id == "child"
    end
  end

  # ---------------------------------------------------------------------------
  # with_options/2 -- error case
  # ---------------------------------------------------------------------------

  describe "with_options/2" do
    test "raises on unknown option" do
      assert_raise ArgumentError, fn ->
        MouseArea.new("ma1", style: :fancy)
      end
    end
  end
end
