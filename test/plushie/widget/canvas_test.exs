defmodule Plushie.Widget.CanvasTest do
  use ExUnit.Case, async: true

  alias Plushie.Canvas.Layer
  alias Plushie.Widget.Canvas

  describe "new/2" do
    test "creates a canvas with the given id and nil defaults" do
      canvas = Canvas.new("my_canvas")

      assert canvas.id == "my_canvas"
      assert canvas.children == []
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
      canvas = Canvas.new("c1", width: 400, height: 300, background: "#ff0000")

      assert canvas.width == 400
      assert canvas.height == 300
      assert canvas.background == "#ff0000"
    end
  end

  describe "container API" do
    test "push adds a Layer child" do
      layer = Layer.new("auto:layer:bg", name: "bg")

      canvas =
        Canvas.new("c1")
        |> Canvas.push(layer)

      assert length(canvas.children) == 1
    end

    test "extend adds multiple Layer children" do
      bg = Layer.new("auto:layer:bg", name: "bg")
      fg = Layer.new("auto:layer:fg", name: "fg")

      canvas =
        Canvas.new("c1")
        |> Canvas.extend([bg, fg])

      assert length(canvas.children) == 2
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

      refute Map.has_key?(node.props, :width)
      refute Map.has_key?(node.props, :height)
      refute Map.has_key?(node.props, :background)
      refute Map.has_key?(node.props, :interactive)
    end

    test "Layer children become child nodes" do
      layer = Layer.new("auto:layer:dots", name: "dots")

      node =
        Canvas.new("c1")
        |> Canvas.push(layer)
        |> Canvas.build()

      assert length(node.children) == 1
      [child] = node.children
      assert child.type == "__layer__"
      assert child.props[:name] == "dots"
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
