defmodule Julep.Canvas.ShapeTest do
  use ExUnit.Case, async: true

  alias Julep.Canvas.Shape

  # -- Basic shapes -----------------------------------------------------------

  describe "rect/5" do
    test "produces a rect descriptor with position and size" do
      result = Shape.rect(10, 20, 100, 50)
      assert result == %{"type" => "rect", "x" => 10, "y" => 20, "w" => 100, "h" => 50}
    end

    test "with fill option" do
      result = Shape.rect(0, 0, 80, 40, fill: "#ff0000")
      assert result["type"] == "rect"
      assert result["fill"] == "#ff0000"
    end

    test "with stroke option" do
      s = Shape.stroke("#000", 2)
      result = Shape.rect(0, 0, 80, 40, stroke: s)
      assert result["stroke"] == %{"color" => "#000", "width" => 2}
    end
  end

  describe "circle/4" do
    test "produces a circle descriptor with center and radius" do
      result = Shape.circle(50, 50, 25)

      assert result == %{"type" => "circle", "x" => 50, "y" => 50, "r" => 25}
    end

    test "accepts fill and stroke options" do
      s = Shape.stroke("#333", 1)
      result = Shape.circle(50, 50, 25, fill: "#0088ff", stroke: s)

      assert result["fill"] == "#0088ff"
      assert result["stroke"]["color"] == "#333"
    end
  end

  describe "line/5" do
    test "produces a line descriptor between two points" do
      result = Shape.line(0, 0, 100, 100)
      assert result == %{"type" => "line", "x1" => 0, "y1" => 0, "x2" => 100, "y2" => 100}
    end

    test "accepts stroke option (no fill -- lines have no interior)" do
      s = Shape.stroke("#333", 1, cap: "round")
      result = Shape.line(0, 0, 50, 50, stroke: s)

      assert result["stroke"]["cap"] == "round"
      refute Map.has_key?(result, "fill")
    end
  end

  describe "text/4" do
    test "produces a text descriptor with content" do
      result = Shape.text(10, 10, "Hello")
      assert result == %{"type" => "text", "x" => 10, "y" => 10, "content" => "Hello"}
    end

    test "with size and font options" do
      result = Shape.text(10, 10, "Hello", size: 16, font: "monospace")
      assert result["size"] == 16
      assert result["font"] == "monospace"
    end

    test "with fill option" do
      result = Shape.text(5, 5, "Colored", fill: "#000000")
      assert result["fill"] == "#000000"
    end
  end

  # -- Path shape -------------------------------------------------------------

  describe "path/2" do
    test "wraps commands in a path descriptor" do
      commands = [Shape.move_to(0, 0), Shape.line_to(100, 0), Shape.close()]
      result = Shape.path(commands)

      assert result["type"] == "path"
      assert result["commands"] == [["move_to", 0, 0], ["line_to", 100, 0], "close"]
    end

    test "accepts fill and stroke options" do
      result = Shape.path([Shape.move_to(0, 0)], fill: "#0088ff", stroke: Shape.stroke("#000", 2))

      assert result["fill"] == "#0088ff"
      assert result["stroke"]["color"] == "#000"
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
    test "push_transform/0 produces a push_transform map" do
      assert Shape.push_transform() == %{"type" => "push_transform"}
    end

    test "pop_transform/0 produces a pop_transform map" do
      assert Shape.pop_transform() == %{"type" => "pop_transform"}
    end

    test "translate/2 produces a translate map with offsets" do
      assert Shape.translate(100, 200) == %{"type" => "translate", "x" => 100, "y" => 200}
    end

    test "rotate/1 produces a rotate map with angle in radians" do
      angle = :math.pi() / 4
      assert Shape.rotate(angle) == %{"type" => "rotate", "angle" => angle}
    end

    test "scale/2 produces a scale map with per-axis factors" do
      assert Shape.scale(2, 3) == %{"type" => "scale", "x" => 2, "y" => 3}
    end

    test "scale/2 supports uniform scaling via same values" do
      result = Shape.scale(1.5, 1.5)
      assert result["x"] == 1.5
      assert result["y"] == 1.5
    end
  end

  # -- Gradient ---------------------------------------------------------------

  describe "linear_gradient/3" do
    test "produces a linear gradient descriptor with start, end, and stops" do
      result = Shape.linear_gradient({0, 0}, {200, 0}, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])

      assert result == %{
               "type" => "linear",
               "start" => [0, 0],
               "end" => [200, 0],
               "stops" => [[0.0, "#ff0000"], [1.0, "#0000ff"]]
             }
    end

    test "usable as a fill value for shapes" do
      gradient = Shape.linear_gradient({0, 0}, {100, 0}, [{0.0, "#000"}, {1.0, "#fff"}])
      rect = Shape.rect(0, 0, 100, 50, fill: gradient)

      assert rect["fill"]["type"] == "linear"
      assert rect["fill"]["stops"] == [[0.0, "#000"], [1.0, "#fff"]]
    end
  end

  # -- Stroke helper ----------------------------------------------------------

  describe "stroke/3" do
    test "produces a basic stroke descriptor with color and width" do
      result = Shape.stroke("#000", 2)
      assert result == %{"color" => "#000", "width" => 2}
    end

    test "with cap option" do
      result = Shape.stroke("#000", 1, cap: "round")
      assert result["cap"] == "round"
    end

    test "with join option" do
      result = Shape.stroke("#000", 1, join: "bevel")
      assert result["join"] == "bevel"
    end

    test "with dash option" do
      result = Shape.stroke("#000", 1, dash: {[5, 3], 0})
      assert result["dash"] == %{"segments" => [5, 3], "offset" => 0}
    end

    test "with all options combined" do
      result = Shape.stroke("#ff0000", 3, cap: "square", join: "miter", dash: {[10, 5], 2})

      assert result["color"] == "#ff0000"
      assert result["width"] == 3
      assert result["cap"] == "square"
      assert result["join"] == "miter"
      assert result["dash"] == %{"segments" => [10, 5], "offset" => 2}
    end
  end

  # -- Image / SVG on canvas --------------------------------------------------

  describe "image/5" do
    test "produces an image descriptor with source, position, and size" do
      result = Shape.image("assets/logo.png", 10, 20, 100, 50)

      assert result == %{
               "type" => "image",
               "source" => "assets/logo.png",
               "x" => 10,
               "y" => 20,
               "w" => 100,
               "h" => 50
             }
    end
  end

  describe "svg/5" do
    test "produces an SVG descriptor with source, position, and size" do
      result = Shape.svg("icons/arrow.svg", 0, 0, 24, 24)

      assert result == %{
               "type" => "svg",
               "source" => "icons/arrow.svg",
               "x" => 0,
               "y" => 0,
               "w" => 24,
               "h" => 24
             }
    end
  end
end
