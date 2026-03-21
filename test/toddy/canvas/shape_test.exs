defmodule Toddy.Canvas.ShapeTest do
  use ExUnit.Case, async: true

  alias Toddy.Canvas.Shape

  alias Toddy.Canvas.Shape.{
    CanvasImage,
    CanvasSvg,
    CanvasText,
    Circle,
    Interactive,
    Line,
    LinearGradient,
    Path,
    PopClip,
    PopTransform,
    PushClip,
    PushTransform,
    Rect,
    Rotate,
    Scale,
    Stroke,
    Translate
  }

  # -- Basic shapes -----------------------------------------------------------

  describe "rect/5" do
    test "produces a rect descriptor with position and size" do
      result = Shape.rect(10, 20, 100, 50)
      assert %Rect{x: 10, y: 20, w: 100, h: 50} = result
    end

    test "with fill option" do
      result = Shape.rect(0, 0, 80, 40, fill: "#ff0000")
      assert %Rect{} = result
      assert result.fill == "#ff0000"
    end

    test "with stroke option" do
      s = Shape.stroke("#000", 2)
      result = Shape.rect(0, 0, 80, 40, stroke: s)
      assert result.stroke == %Stroke{color: "#000", width: 2}
    end
  end

  describe "circle/4" do
    test "produces a circle descriptor with center and radius" do
      result = Shape.circle(50, 50, 25)
      assert %Circle{x: 50, y: 50, r: 25} = result
    end

    test "accepts fill and stroke options" do
      s = Shape.stroke("#333", 1)
      result = Shape.circle(50, 50, 25, fill: "#0088ff", stroke: s)

      assert result.fill == "#0088ff"
      assert result.stroke.color == "#333"
    end
  end

  describe "line/5" do
    test "produces a line descriptor between two points" do
      result = Shape.line(0, 0, 100, 100)
      assert %Line{x1: 0, y1: 0, x2: 100, y2: 100} = result
    end

    test "accepts stroke option (no fill -- lines have no interior)" do
      s = Shape.stroke("#333", 1, cap: "round")
      result = Shape.line(0, 0, 50, 50, stroke: s)

      assert result.stroke.cap == "round"
      refute Map.has_key?(Map.from_struct(result), :fill)
    end
  end

  describe "text/4" do
    test "produces a text descriptor with content" do
      result = Shape.text(10, 10, "Hello")
      assert %CanvasText{x: 10, y: 10, content: "Hello"} = result
    end

    test "with size and font options" do
      result = Shape.text(10, 10, "Hello", size: 16, font: "monospace")
      assert result.size == 16
      assert result.font == "monospace"
    end

    test "with fill option" do
      result = Shape.text(5, 5, "Colored", fill: "#000000")
      assert result.fill == "#000000"
    end
  end

  # -- Path shape -------------------------------------------------------------

  describe "path/2" do
    test "wraps commands in a path descriptor" do
      commands = [Shape.move_to(0, 0), Shape.line_to(100, 0), Shape.close()]
      result = Shape.path(commands)

      assert %Path{} = result
      assert result.commands == [["move_to", 0, 0], ["line_to", 100, 0], "close"]
    end

    test "accepts fill and stroke options" do
      result = Shape.path([Shape.move_to(0, 0)], fill: "#0088ff", stroke: Shape.stroke("#000", 2))

      assert result.fill == "#0088ff"
      assert result.stroke.color == "#000"
    end
  end

  # -- Path commands ----------------------------------------------------------

  describe "path commands" do
    test "move_to/2 produces a tagged list" do
      assert Shape.move_to(10, 20) == ["move_to", 10, 20]
    end

    test "line_to/2 produces a tagged list" do
      assert Shape.line_to(30, 40) == ["line_to", 30, 40]
    end

    test "bezier_to/6 produces a tagged list with two control points and endpoint" do
      result = Shape.bezier_to(10, 20, 30, 40, 50, 60)
      assert result == ["bezier_to", 10, 20, 30, 40, 50, 60]
    end

    test "quadratic_to/4 produces a tagged list with control point and endpoint" do
      result = Shape.quadratic_to(10, 20, 30, 40)
      assert result == ["quadratic_to", 10, 20, 30, 40]
    end

    test "arc/5 produces a tagged list with center, radius, and angle range" do
      result = Shape.arc(50, 50, 25, 0, :math.pi())
      assert result == ["arc", 50, 50, 25, 0, :math.pi()]
    end

    test "arc_to/5 produces a tagged list with two tangent points and radius" do
      result = Shape.arc_to(0, 0, 100, 0, 10)
      assert result == ["arc_to", 0, 0, 100, 0, 10]
    end

    test "ellipse/7 produces a tagged list with center, radii, rotation, and angle range" do
      result = Shape.ellipse(50, 50, 30, 20, 0, 0, :math.pi() * 2)
      assert result == ["ellipse", 50, 50, 30, 20, 0, 0, :math.pi() * 2]
    end

    test "rounded_rect/5 produces a tagged list with position, size, and corner radius" do
      result = Shape.rounded_rect(10, 10, 80, 40, 8)
      assert result == ["rounded_rect", 10, 10, 80, 40, 8]
    end

    test "close/0 returns the string \"close\"" do
      assert Shape.close() == "close"
    end
  end

  # -- Transform commands -----------------------------------------------------

  describe "transform commands" do
    test "push_transform/0 produces a PushTransform struct" do
      assert Shape.push_transform() == %PushTransform{}
    end

    test "pop_transform/0 produces a PopTransform struct" do
      assert Shape.pop_transform() == %PopTransform{}
    end

    test "translate/2 produces a Translate struct with offsets" do
      assert Shape.translate(100, 200) == %Translate{x: 100, y: 200}
    end

    test "rotate/1 produces a Rotate struct with angle in radians" do
      angle = :math.pi() / 4
      assert Shape.rotate(angle) == %Rotate{angle: angle}
    end

    test "scale/2 produces a Scale struct with per-axis factors" do
      assert Shape.scale(2, 3) == %Scale{x: 2, y: 3}
    end

    test "scale/2 supports uniform scaling via same values" do
      result = Shape.scale(1.5, 1.5)
      assert result.x == 1.5
      assert result.y == 1.5
    end
  end

  # -- Gradient ---------------------------------------------------------------

  describe "linear_gradient/3" do
    test "produces a linear gradient descriptor with from, to, and stops" do
      result = Shape.linear_gradient({0, 0}, {200, 0}, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])

      assert %LinearGradient{
               from: {0, 0},
               to: {200, 0},
               stops: [{+0.0, "#ff0000"}, {1.0, "#0000ff"}]
             } = result
    end

    test "usable as a fill value for shapes" do
      gradient = Shape.linear_gradient({0, 0}, {100, 0}, [{0.0, "#000"}, {1.0, "#fff"}])
      rect = Shape.rect(0, 0, 100, 50, fill: gradient)

      assert %LinearGradient{} = rect.fill
      assert rect.fill.stops == [{0.0, "#000"}, {1.0, "#fff"}]
    end
  end

  # -- Fill rule --------------------------------------------------------------

  describe "fill_rule option" do
    test "fill_rule :even_odd adds fill_rule to shape" do
      result = Shape.rect(0, 0, 100, 50, fill: "#ff0000", fill_rule: :even_odd)
      assert result.fill_rule == "even_odd"
    end

    test "fill_rule :non_zero adds explicit fill_rule to shape" do
      result = Shape.circle(50, 50, 25, fill: "#00ff00", fill_rule: :non_zero)
      assert result.fill_rule == "non_zero"
    end

    test "fill_rule is nil when not set" do
      result = Shape.rect(0, 0, 100, 50, fill: "#ff0000")
      assert result.fill_rule == nil
    end

    test "fill_rule works on path shapes" do
      commands = [Shape.move_to(0, 0), Shape.line_to(100, 0), Shape.close()]
      result = Shape.path(commands, fill: "#0088ff", fill_rule: :even_odd)
      assert result.fill_rule == "even_odd"
    end
  end

  # -- Stroke helper ----------------------------------------------------------

  describe "stroke/3" do
    test "produces a basic stroke descriptor with color and width" do
      result = Shape.stroke("#000", 2)
      assert result == %Stroke{color: "#000", width: 2}
    end

    test "with cap option" do
      result = Shape.stroke("#000", 1, cap: "round")
      assert result.cap == "round"
    end

    test "with join option" do
      result = Shape.stroke("#000", 1, join: "bevel")
      assert result.join == "bevel"
    end

    test "with dash option" do
      result = Shape.stroke("#000", 1, dash: {[5, 3], 0})
      assert result.dash == %{segments: [5, 3], offset: 0}
    end

    test "with all options combined" do
      result = Shape.stroke("#ff0000", 3, cap: "square", join: "miter", dash: {[10, 5], 2})

      assert result.color == "#ff0000"
      assert result.width == 3
      assert result.cap == "square"
      assert result.join == "miter"
      assert result.dash == %{segments: [10, 5], offset: 2}
    end
  end

  # -- Image / SVG on canvas --------------------------------------------------

  describe "image/5" do
    test "produces an image descriptor with source, position, and size" do
      result = Shape.image("assets/logo.png", 10, 20, 100, 50)

      assert %CanvasImage{
               source: "assets/logo.png",
               x: 10,
               y: 20,
               w: 100,
               h: 50
             } = result
    end
  end

  describe "svg/5" do
    test "produces an SVG descriptor with source, position, and size" do
      result = Shape.svg("icons/arrow.svg", 0, 0, 24, 24)

      assert %CanvasSvg{
               source: "icons/arrow.svg",
               x: 0,
               y: 0,
               w: 24,
               h: 24
             } = result
    end
  end

  # -- Clipping commands ------------------------------------------------------

  describe "push_clip/4" do
    test "produces a push_clip descriptor with position and size" do
      result = Shape.push_clip(10, 20, 100, 80)
      assert result == %PushClip{x: 10, y: 20, w: 100, h: 80}
    end

    test "accepts float coordinates" do
      result = Shape.push_clip(10.5, 20.5, 100.0, 80.0)
      assert result.x == 10.5
      assert result.y == 20.5
    end
  end

  describe "pop_clip/0" do
    test "produces a pop_clip descriptor" do
      assert Shape.pop_clip() == %PopClip{}
    end
  end

  describe "clip region sequences" do
    test "push_clip and pop_clip bracket shapes in a valid sequence" do
      shapes = [
        Shape.push_clip(10, 10, 100, 80),
        Shape.rect(0, 0, 200, 200, fill: "#ff0000"),
        Shape.circle(50, 50, 25, fill: "#00ff00"),
        Shape.pop_clip()
      ]

      assert length(shapes) == 4
      assert %PushClip{} = hd(shapes)
      assert %PopClip{} = List.last(shapes)

      # Interior shapes are unchanged
      assert %Rect{} = Enum.at(shapes, 1)
      assert %Circle{} = Enum.at(shapes, 2)
    end

    test "nested clip regions produce valid sequences" do
      shapes = [
        Shape.push_clip(0, 0, 200, 200),
        Shape.push_clip(10, 10, 100, 100),
        Shape.rect(0, 0, 50, 50, fill: "#f00"),
        Shape.pop_clip(),
        Shape.rect(0, 0, 150, 150, fill: "#0f0"),
        Shape.pop_clip()
      ]

      assert length(shapes) == 6

      assert [
               %PushClip{},
               %PushClip{},
               %Rect{},
               %PopClip{},
               %Rect{},
               %PopClip{}
             ] = shapes
    end
  end

  # -- Per-shape opacity ------------------------------------------------------

  describe "opacity option" do
    test "rect accepts opacity" do
      result = Shape.rect(0, 0, 100, 50, fill: "#ff0000", opacity: 0.5)
      assert result.opacity == 0.5
    end

    test "circle accepts opacity" do
      result = Shape.circle(50, 50, 25, fill: "#00ff00", opacity: 0.3)
      assert result.opacity == 0.3
    end

    test "line accepts opacity" do
      result = Shape.line(0, 0, 100, 100, stroke: Shape.stroke("#000", 1), opacity: 0.8)
      assert result.opacity == 0.8
    end

    test "text accepts opacity" do
      result = Shape.text(10, 10, "Faded", fill: "#000", opacity: 0.25)
      assert result.opacity == 0.25
    end

    test "path accepts opacity" do
      result = Shape.path([Shape.move_to(0, 0)], fill: "#fff", opacity: 0.1)
      assert result.opacity == 0.1
    end

    test "opacity is nil when not set" do
      result = Shape.rect(0, 0, 100, 50, fill: "#ff0000")
      assert result.opacity == nil
    end
  end

  # -- Text alignment ---------------------------------------------------------

  describe "text alignment options" do
    test "text accepts align_x" do
      result = Shape.text(100, 50, "Centered", fill: "#000", align_x: "center")
      assert result.align_x == "center"
    end

    test "text accepts align_y" do
      result = Shape.text(100, 50, "Middle", fill: "#000", align_y: "center")
      assert result.align_y == "center"
    end

    test "text accepts both align_x and align_y" do
      result = Shape.text(100, 50, "Both", fill: "#000", align_x: "right", align_y: "bottom")
      assert result.align_x == "right"
      assert result.align_y == "bottom"
    end

    test "alignment keys are nil when not set" do
      result = Shape.text(10, 10, "Default")
      assert result.align_x == nil
      assert result.align_y == nil
    end
  end

  # -- Interactive shapes -----------------------------------------------------

  describe "interactive_descriptor/2" do
    test "returns metadata tuple with Interactive struct" do
      {:__canvas_meta__, :interactive, %Interactive{} = interactive} =
        Shape.interactive_descriptor("btn", on_click: true)

      assert interactive.id == "btn"
      assert interactive.on_click == true
    end
  end

  describe "Interactive.new/1" do
    test "validates unknown keys" do
      assert_raise ArgumentError, ~r/unknown interactive option/, fn ->
        Interactive.new(id: "x", on_clck: true)
      end
    end

    test "requires id" do
      assert_raise KeyError, fn ->
        Interactive.new(on_click: true)
      end
    end
  end
end
