defmodule Toddy.Widget.TooltipTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Tooltip

  describe "new/3" do
    test "creates a tooltip with the given id, tip, and nil defaults" do
      tt = Tooltip.new("tt1", "Help text")
      assert tt.id == "tt1"
      assert tt.tip == "Help text"
      assert tt.position == nil
      assert tt.gap == nil
      assert tt.padding == nil
      assert tt.snap_within_viewport == nil
      assert tt.delay == nil
      assert tt.style == nil
      assert tt.children == []
    end

    test "accepts keyword options" do
      tt = Tooltip.new("tt1", "Help", position: :bottom, gap: 4)
      assert tt.position == :bottom
      assert tt.gap == 4
    end
  end

  describe "builder functions" do
    test "position/2 sets the position field" do
      tt = Tooltip.new("tt1", "Tip") |> Tooltip.position(:right)
      assert tt.position == :right
    end

    test "gap/2 sets the gap field" do
      tt = Tooltip.new("tt1", "Tip") |> Tooltip.gap(8)
      assert tt.gap == 8
    end

    test "padding/2 sets the padding field" do
      tt = Tooltip.new("tt1", "Tip") |> Tooltip.padding(12)
      assert tt.padding == 12
    end

    test "snap_within_viewport/2 sets the snap_within_viewport field" do
      tt = Tooltip.new("tt1", "Tip") |> Tooltip.snap_within_viewport(false)
      assert tt.snap_within_viewport == false
    end

    test "style/2 sets the style field" do
      tt = Tooltip.new("tt1", "Tip") |> Tooltip.style(:dark)
      assert tt.style == :dark
    end

    test "delay/2 sets the delay field" do
      tt = Tooltip.new("tt1", "Tip") |> Tooltip.delay(500)
      assert tt.delay == 500
    end
  end

  describe "push/2 and extend/2" do
    test "push/2 appends a single child" do
      child = %{id: "btn1", type: "button", props: %{}, children: []}
      tt = Tooltip.new("tt1", "Tip") |> Tooltip.push(child)
      assert length(tt.children) == 1
      assert hd(tt.children) == child
    end

    test "extend/2 appends multiple children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      tt = Tooltip.new("tt1", "Tip") |> Tooltip.extend([c1, c2])
      assert length(tt.children) == 2
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Tooltip.new("tt1", "Tip") |> Tooltip.build()
      assert node.type == "tooltip"
      assert node.id == "tt1"
    end

    test "always includes the tip prop" do
      node = Tooltip.new("tt1", "Help text") |> Tooltip.build()
      assert node.props[:tip] == "Help text"
    end

    test "includes non-nil props" do
      node =
        Tooltip.new("tt1", "Tip", position: :top, gap: 5, style: :primary)
        |> Tooltip.build()

      assert node.props[:position] == "top"
      assert node.props[:gap] == 5
      assert node.props[:style] == "primary"
    end

    test "includes delay in props when set" do
      node = Tooltip.new("tt1", "Tip") |> Tooltip.delay(300) |> Tooltip.build()
      assert node.props[:delay] == 300
    end

    test "omits nil props" do
      node = Tooltip.new("tt1", "Tip") |> Tooltip.build()
      refute Map.has_key?(node.props, "position")
      refute Map.has_key?(node.props, "gap")
      refute Map.has_key?(node.props, "padding")
      refute Map.has_key?(node.props, "snap_within_viewport")
      refute Map.has_key?(node.props, "delay")
      refute Map.has_key?(node.props, "style")
    end

    test "preserves false for snap_within_viewport" do
      node =
        Tooltip.new("tt1", "Tip")
        |> Tooltip.snap_within_viewport(false)
        |> Tooltip.build()

      assert node.props[:snap_within_viewport] == false
    end
  end

  describe "with_options/2" do
    test "routes all options correctly" do
      tt =
        Tooltip.new("tt1", "Tip")
        |> Tooltip.with_options(
          position: :left,
          gap: 6,
          padding: 10,
          snap_within_viewport: true,
          delay: 200,
          style: :warning
        )

      assert tt.position == :left
      assert tt.gap == 6
      assert tt.padding == 10
      assert tt.snap_within_viewport == true
      assert tt.delay == 200
      assert tt.style == :warning
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Tooltip.new("tt1", "Tip", bogus: true)
      end
    end
  end
end
