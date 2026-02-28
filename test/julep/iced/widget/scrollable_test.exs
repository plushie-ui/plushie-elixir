defmodule Julep.Iced.Widget.ScrollableTest do
  use ExUnit.Case, async: true

  alias Julep.Iced.Widget.Scrollable

  describe "new/2" do
    test "creates a scrollable with the given id and nil defaults" do
      s = Scrollable.new("scr1")
      assert s.id == "scr1"
      assert s.width == nil
      assert s.height == nil
      assert s.direction == nil
      assert s.spacing == nil
      assert s.scrollbar_width == nil
      assert s.scrollbar_margin == nil
      assert s.scroller_width == nil
      assert s.anchor == nil
      assert s.on_scroll == nil
      assert s.auto_scroll == nil
      assert s.children == []
    end

    test "accepts keyword options" do
      s = Scrollable.new("scr1", direction: :vertical, height: 400)
      assert s.direction == :vertical
      assert s.height == 400
    end
  end

  describe "builder functions" do
    test "width/2 sets the width field" do
      s = Scrollable.new("scr1") |> Scrollable.width(:fill)
      assert s.width == :fill
    end

    test "height/2 sets the height field" do
      s = Scrollable.new("scr1") |> Scrollable.height(300)
      assert s.height == 300
    end

    test "direction/2 sets the direction field" do
      s = Scrollable.new("scr1") |> Scrollable.direction(:horizontal)
      assert s.direction == :horizontal
    end

    test "spacing/2 sets the spacing field" do
      s = Scrollable.new("scr1") |> Scrollable.spacing(5)
      assert s.spacing == 5
    end

    test "scrollbar_width/2 sets the scrollbar_width field" do
      s = Scrollable.new("scr1") |> Scrollable.scrollbar_width(12)
      assert s.scrollbar_width == 12
    end

    test "scrollbar_margin/2 sets the scrollbar_margin field" do
      s = Scrollable.new("scr1") |> Scrollable.scrollbar_margin(4)
      assert s.scrollbar_margin == 4
    end

    test "scroller_width/2 sets the scroller_width field" do
      s = Scrollable.new("scr1") |> Scrollable.scroller_width(8)
      assert s.scroller_width == 8
    end

    test "anchor/2 sets the anchor field" do
      s = Scrollable.new("scr1") |> Scrollable.anchor(:end)
      assert s.anchor == :end
    end

    test "on_scroll/2 sets the on_scroll field" do
      s = Scrollable.new("scr1") |> Scrollable.on_scroll(true)
      assert s.on_scroll == true
    end

    test "auto_scroll/2 sets the auto_scroll field" do
      s = Scrollable.new("scr1") |> Scrollable.auto_scroll(true)
      assert s.auto_scroll == true
    end
  end

  describe "push/2 and extend/2" do
    test "push/2 appends a single child" do
      child = %{id: "c1", type: "text", props: %{}, children: []}
      s = Scrollable.new("scr1") |> Scrollable.push(child)
      assert length(s.children) == 1
      assert hd(s.children) == child
    end

    test "extend/2 appends multiple children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      s = Scrollable.new("scr1") |> Scrollable.extend([c1, c2])
      assert length(s.children) == 2
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Scrollable.new("scr1") |> Scrollable.build()
      assert node.type == "scrollable"
      assert node.id == "scr1"
      assert node.children == []
    end

    test "includes non-nil props" do
      node =
        Scrollable.new("scr1", direction: :both, spacing: 4, on_scroll: true)
        |> Scrollable.build()

      assert node.props["direction"] == "both"
      assert node.props["spacing"] == 4
      assert node.props["on_scroll"] == true
    end

    test "omits nil props" do
      node = Scrollable.new("scr1") |> Scrollable.build()
      refute Map.has_key?(node.props, "direction")
      refute Map.has_key?(node.props, "spacing")
      refute Map.has_key?(node.props, "scrollbar_width")
      refute Map.has_key?(node.props, "anchor")
      refute Map.has_key?(node.props, "on_scroll")
    end

    test "preserves false values in props" do
      node = Scrollable.new("scr1") |> Scrollable.on_scroll(false) |> Scrollable.build()
      assert node.props["on_scroll"] == false
    end
  end

  describe "with_options/2" do
    test "routes all options correctly" do
      s =
        Scrollable.new("scr1")
        |> Scrollable.with_options(
          width: :fill,
          height: 500,
          direction: :vertical,
          spacing: 8,
          scrollbar_width: 10,
          scrollbar_margin: 2,
          scroller_width: 6,
          anchor: :start,
          on_scroll: true,
          auto_scroll: true
        )

      assert s.width == :fill
      assert s.height == 500
      assert s.direction == :vertical
      assert s.spacing == 8
      assert s.scrollbar_width == 10
      assert s.scrollbar_margin == 2
      assert s.scroller_width == 6
      assert s.anchor == :start
      assert s.on_scroll == true
      assert s.auto_scroll == true
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Scrollable.new("scr1", bogus: true)
      end
    end
  end
end
