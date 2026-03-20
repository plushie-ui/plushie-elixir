defmodule Toddy.Widget.ContainerTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Container

  describe "new/2" do
    test "creates a container with the given id and nil defaults" do
      c = Container.new("c1")
      assert c.id == "c1"
      assert c.padding == nil
      assert c.width == nil
      assert c.height == nil
      assert c.max_width == nil
      assert c.max_height == nil
      assert c.center == nil
      assert c.clip == nil
      assert c.align_x == nil
      assert c.align_y == nil
      assert c.background == nil
      assert c.color == nil
      assert c.border == nil
      assert c.shadow == nil
      assert c.style == nil
      assert c.children == []
    end

    test "accepts keyword options" do
      c = Container.new("c1", padding: 10, clip: true)
      assert c.padding == 10
      assert c.clip == true
    end
  end

  describe "builder functions" do
    test "padding/2 sets the padding field" do
      c = Container.new("c1") |> Container.padding(20)
      assert c.padding == 20
    end

    test "width/2 sets the width field" do
      c = Container.new("c1") |> Container.width(:fill)
      assert c.width == :fill
    end

    test "height/2 sets the height field" do
      c = Container.new("c1") |> Container.height(100)
      assert c.height == 100
    end

    test "max_width/2 sets the max_width field" do
      c = Container.new("c1") |> Container.max_width(500)
      assert c.max_width == 500
    end

    test "max_height/2 sets the max_height field" do
      c = Container.new("c1") |> Container.max_height(400)
      assert c.max_height == 400
    end

    test "center/1 defaults to true" do
      c = Container.new("c1") |> Container.center()
      assert c.center == true
    end

    test "center/2 sets the center field" do
      c = Container.new("c1") |> Container.center(false)
      assert c.center == false
    end

    test "clip/2 sets the clip field" do
      c = Container.new("c1") |> Container.clip(true)
      assert c.clip == true
    end

    test "align_x/2 sets the align_x field" do
      c = Container.new("c1") |> Container.align_x(:center)
      assert c.align_x == :center
    end

    test "align_y/2 sets the align_y field" do
      c = Container.new("c1") |> Container.align_y(:bottom)
      assert c.align_y == :bottom
    end

    test "background/2 sets the background field" do
      c = Container.new("c1") |> Container.background("#ff0000")
      assert c.background == "#ff0000"
    end

    test "color/2 casts and sets the color field" do
      c = Container.new("c1") |> Container.color(:red)
      # Color.cast normalizes named atoms to hex
      assert is_binary(c.color)
    end

    test "border/2 sets the border field" do
      b = %{color: "#000000", width: 1, radius: 4}
      c = Container.new("c1") |> Container.border(b)
      assert c.border == b
    end

    test "shadow/2 sets the shadow field" do
      s = %Toddy.Type.Shadow{color: "#000000", offset_x: 2, offset_y: 2, blur_radius: 4}
      c = Container.new("c1") |> Container.shadow(s)
      assert c.shadow == s
    end

    test "style/2 sets the style field" do
      c = Container.new("c1") |> Container.style(:primary)
      assert c.style == :primary
    end
  end

  describe "convenience alignment builders" do
    test "center_x/1 sets width to :fill and align_x to :center" do
      c = Container.new("c1") |> Container.center_x()
      assert c.width == :fill
      assert c.align_x == :center
    end

    test "center_x/2 sets custom width and align_x to :center" do
      c = Container.new("c1") |> Container.center_x(200)
      assert c.width == 200
      assert c.align_x == :center
    end

    test "center_y/1 sets height to :fill and align_y to :center" do
      c = Container.new("c1") |> Container.center_y()
      assert c.height == :fill
      assert c.align_y == :center
    end

    test "center_y/2 sets custom height and align_y to :center" do
      c = Container.new("c1") |> Container.center_y(300)
      assert c.height == 300
      assert c.align_y == :center
    end

    test "align_left/1 sets width to :fill and align_x to :left" do
      c = Container.new("c1") |> Container.align_left()
      assert c.width == :fill
      assert c.align_x == :left
    end

    test "align_left/2 sets custom width and align_x to :left" do
      c = Container.new("c1") |> Container.align_left(150)
      assert c.width == 150
      assert c.align_x == :left
    end

    test "align_right/1 sets width to :fill and align_x to :right" do
      c = Container.new("c1") |> Container.align_right()
      assert c.width == :fill
      assert c.align_x == :right
    end

    test "align_right/2 sets custom width and align_x to :right" do
      c = Container.new("c1") |> Container.align_right(250)
      assert c.width == 250
      assert c.align_x == :right
    end

    test "align_top/1 sets height to :fill and align_y to :top" do
      c = Container.new("c1") |> Container.align_top()
      assert c.height == :fill
      assert c.align_y == :top
    end

    test "align_bottom/1 sets height to :fill and align_y to :bottom" do
      c = Container.new("c1") |> Container.align_bottom()
      assert c.height == :fill
      assert c.align_y == :bottom
    end

    test "align_bottom/2 sets custom height and align_y to :bottom" do
      c = Container.new("c1") |> Container.align_bottom(500)
      assert c.height == 500
      assert c.align_y == :bottom
    end
  end

  describe "push/2 and extend/2" do
    test "push/2 appends a single child" do
      child = %{id: "txt", type: "text", props: %{}, children: []}
      c = Container.new("c1") |> Container.push(child)
      assert length(c.children) == 1
    end

    test "extend/2 appends multiple children" do
      children = [
        %{id: "t1", type: "text", props: %{}, children: []},
        %{id: "t2", type: "text", props: %{}, children: []}
      ]

      c = Container.new("c1") |> Container.extend(children)
      assert length(c.children) == 2
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Container.new("c1") |> Container.build()
      assert node.type == "container"
      assert node.id == "c1"
    end

    test "includes non-nil props" do
      node = Container.new("c1", padding: 10, center: true, style: :dark) |> Container.build()
      assert node.props[:padding] == 10
      assert node.props[:center] == true
      assert node.props[:style] == :dark
    end

    test "omits nil props" do
      node = Container.new("c1") |> Container.build()
      refute Map.has_key?(node.props, "padding")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "style")
      refute Map.has_key?(node.props, "background")
    end
  end

  describe "with_options/2" do
    test "routes all options correctly" do
      c =
        Container.new("c1")
        |> Container.with_options(
          padding: 5,
          width: :fill,
          height: 200,
          max_width: 800,
          max_height: 600,
          center: true,
          clip: true,
          align_x: :left,
          align_y: :top,
          style: :primary
        )

      assert c.padding == 5
      assert c.width == :fill
      assert c.height == 200
      assert c.max_width == 800
      assert c.max_height == 600
      assert c.center == true
      assert c.clip == true
      assert c.align_x == :left
      assert c.align_y == :top
      assert c.style == :primary
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Container.new("c1", bogus: 42)
      end
    end
  end
end
