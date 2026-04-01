defmodule Plushie.Widget.CanvasTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.Canvas

  describe "new/2" do
    test "creates a canvas with the given id and nil defaults" do
      canvas = Canvas.new("my_canvas")

      assert canvas.id == "my_canvas"
      assert canvas.layers == nil
      assert canvas.width == nil
      assert canvas.height == nil
      assert canvas.background == nil
      assert canvas.interactive == nil
      assert canvas.on_press == nil
      assert canvas.on_release == nil
      assert canvas.on_move == nil
      assert canvas.on_scroll == nil
    end

    test "accepts keyword options" do
      layers = %{"bg" => [%{"type" => "rect", "x" => 0, "y" => 0, "w" => 100, "h" => 100}]}

      canvas = Canvas.new("c1", width: 400, height: 300, background: "#ff0000", layers: layers)

      assert canvas.width == 400
      assert canvas.height == 300
      assert canvas.background == "#ff0000"
      assert canvas.layers == layers
    end
  end

  describe "layers/2" do
    test "replaces the entire layers map" do
      layers = %{
        "foreground" => [%{"type" => "circle", "x" => 50, "y" => 50, "r" => 25}],
        "background" => [%{"type" => "rect", "x" => 0, "y" => 0, "w" => 100, "h" => 100}]
      }

      canvas = Canvas.new("c1") |> Canvas.layers(layers)
      assert canvas.layers == layers
    end
  end

  describe "layer/3" do
    test "adds a named layer to a canvas with no existing layers" do
      shapes = [%{"type" => "line", "x1" => 0, "y1" => 0, "x2" => 100, "y2" => 100}]
      canvas = Canvas.new("c1") |> Canvas.layer("grid", shapes)

      assert canvas.layers == %{"grid" => shapes}
    end

    test "merges a new layer with existing layers" do
      bg = [%{"type" => "rect", "x" => 0, "y" => 0, "w" => 100, "h" => 100}]
      fg = [%{"type" => "circle", "x" => 50, "y" => 50, "r" => 10}]

      canvas =
        Canvas.new("c1")
        |> Canvas.layer("background", bg)
        |> Canvas.layer("foreground", fg)

      assert canvas.layers == %{"background" => bg, "foreground" => fg}
    end

    test "replaces an existing layer by name" do
      old_shapes = [%{"type" => "rect", "x" => 0, "y" => 0, "w" => 50, "h" => 50}]
      new_shapes = [%{"type" => "rect", "x" => 0, "y" => 0, "w" => 100, "h" => 100}]

      canvas =
        Canvas.new("c1")
        |> Canvas.layer("bg", old_shapes)
        |> Canvas.layer("bg", new_shapes)

      assert canvas.layers["bg"] == new_shapes
    end
  end

  describe "width/2 and height/2" do
    test "set dimension values" do
      canvas = Canvas.new("c1") |> Canvas.width(640) |> Canvas.height(480)

      assert canvas.width == 640
      assert canvas.height == 480
    end

    test "accept :fill length" do
      canvas = Canvas.new("c1") |> Canvas.width(:fill) |> Canvas.height(:fill)

      assert canvas.width == :fill
      assert canvas.height == :fill
    end
  end

  describe "background/2" do
    test "stores the color value" do
      canvas = Canvas.new("c1") |> Canvas.background("#00ff00")
      assert canvas.background == "#00ff00"
    end
  end

  describe "interactive event builders" do
    test "interactive/2 enables all mouse events" do
      canvas = Canvas.new("c1") |> Canvas.interactive(true)
      assert canvas.interactive == true
    end

    test "on_press/2 enables press events" do
      canvas = Canvas.new("c1") |> Canvas.on_press(true)
      assert canvas.on_press == true
    end

    test "on_release/2 enables release events" do
      canvas = Canvas.new("c1") |> Canvas.on_release(true)
      assert canvas.on_release == true
    end

    test "on_move/2 enables move events" do
      canvas = Canvas.new("c1") |> Canvas.on_move(true)
      assert canvas.on_move == true
    end

    test "on_scroll/2 enables scroll events" do
      canvas = Canvas.new("c1") |> Canvas.on_scroll(true)
      assert canvas.on_scroll == true
    end

    test "individual event flags can be mixed" do
      canvas =
        Canvas.new("c1")
        |> Canvas.on_press(true)
        |> Canvas.on_move(true)

      assert canvas.on_press == true
      assert canvas.on_move == true
      assert canvas.on_release == nil
      assert canvas.on_scroll == nil
      assert canvas.interactive == nil
    end
  end

  describe "build/1" do
    test "produces a node with correct type and id" do
      node = Canvas.new("drawing") |> Canvas.build()

      assert node.id == "drawing"
      assert node.type == "canvas"
      assert node.children == []
    end

    test "omits nil props from the output" do
      node = Canvas.new("c1") |> Canvas.build()

      refute Map.has_key?(node.props, :layers)
      refute Map.has_key?(node.props, :width)
      refute Map.has_key?(node.props, :height)
      refute Map.has_key?(node.props, :background)
      refute Map.has_key?(node.props, :interactive)
    end

    test "includes layers in props" do
      shapes = [%{"type" => "circle", "x" => 10, "y" => 10, "r" => 5}]

      node =
        Canvas.new("c1")
        |> Canvas.layer("dots", shapes)
        |> Canvas.build()

      assert node.props[:layers] == %{"dots" => shapes}
    end

    test "includes all set props" do
      node =
        Canvas.new("c1",
          width: 800,
          height: 600,
          background: "#000000",
          interactive: true
        )
        |> Canvas.build()

      assert node.props[:width] == 800
      assert node.props[:height] == 600
      assert node.props[:background] == "#000000"
      assert node.props[:interactive] == true
    end

    test "boolean false is preserved in props (not stripped like nil)" do
      node =
        Canvas.new("c1")
        |> Canvas.interactive(false)
        |> Canvas.on_press(false)
        |> Canvas.build()

      assert node.props[:interactive] == false
      assert node.props[:on_press] == false
    end
  end

  describe "with_options/2" do
    test "raises on unknown option" do
      assert_raise ArgumentError, fn ->
        Canvas.new("c1", bogus: true)
      end
    end
  end
end
