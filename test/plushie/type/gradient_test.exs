defmodule Plushie.Type.GradientTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Gradient

  describe "linear/2" do
    test "creates a linear gradient with angle and stops" do
      grad = Gradient.linear(0.0, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])

      assert grad.type == "linear"
      assert grad.angle == 0.0

      assert grad.stops == [
               %{offset: 0.0, color: "#ff0000"},
               %{offset: 1.0, color: "#0000ff"}
             ]
    end

    test "accepts single stop" do
      grad = Gradient.linear(1.57, [{0.5, "#00ff00"}])
      assert length(grad.stops) == 1
      assert hd(grad.stops) == %{offset: 0.5, color: "#00ff00"}
    end

    test "accepts empty stops list" do
      grad = Gradient.linear(0, [])
      assert grad.stops == []
    end

    test "preserves angle in radians" do
      grad = Gradient.linear(3.14159, [{0.0, "#000"}, {1.0, "#fff"}])
      assert_in_delta grad.angle, 3.14159, 0.00001
    end

    test "converts RGBA map colors to hex strings" do
      color = %{r: 1.0, g: 0.0, b: 0.0, a: 0.5}
      grad = Gradient.linear(0, [{0.0, color}])
      assert hd(grad.stops).color == "#ff000080"
    end
  end

  describe "encode/1" do
    test "passes through the gradient map unchanged" do
      grad = Gradient.linear(0.0, [{0.0, "#000"}, {1.0, "#fff"}])
      assert Gradient.encode(grad) == grad
    end
  end
end
