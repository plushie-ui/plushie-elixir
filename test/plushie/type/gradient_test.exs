defmodule Plushie.Type.GradientTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Gradient

  describe "linear/3" do
    test "creates a linear gradient with coordinates and stops" do
      grad = Gradient.linear({0, 0}, {100, 100}, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])

      assert grad.from == {0, 0}
      assert grad.to == {100, 100}

      assert grad.stops == [
               {0.0, "#ff0000"},
               {1.0, "#0000ff"}
             ]
    end

    test "accepts single stop" do
      grad = Gradient.linear({0, 0}, {1, 1}, [{0.5, "#00ff00"}])
      assert length(grad.stops) == 1
      assert hd(grad.stops) == {0.5, "#00ff00"}
    end

    test "accepts empty stops list" do
      grad = Gradient.linear({0, 0}, {1, 0}, [])
      assert grad.stops == []
    end

    test "converts RGBA map colors to hex strings" do
      color = %{r: 1.0, g: 0.0, b: 0.0, a: 0.5}
      grad = Gradient.linear({0, 0}, {1, 1}, [{0.0, color}])
      assert elem(hd(grad.stops), 1) == "#ff000080"
    end
  end

  describe "linear_from_angle/2" do
    test "creates gradient from angle in degrees" do
      grad = Gradient.linear_from_angle(90, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])

      assert is_tuple(grad.from)
      assert is_tuple(grad.to)
      assert length(grad.stops) == 2
    end

    test "0 degrees points right" do
      grad = Gradient.linear_from_angle(0, [{0.0, "#000"}, {1.0, "#fff"}])
      {fx, _fy} = grad.from
      {tx, _ty} = grad.to
      assert tx > fx
    end
  end

  describe "encode/1" do
    test "produces unified wire format with start/end and array stops" do
      grad = Gradient.linear({10, 20}, {90, 80}, [{0.0, "#000"}, {1.0, "#fff"}])
      encoded = Gradient.encode(grad)

      refute Map.has_key?(encoded, :__struct__)
      assert encoded.type == "linear"
      assert encoded.start == [10, 20]
      assert encoded[:end] == [90, 80]
      assert encoded.stops == [[0.0, "#000000"], [1.0, "#ffffff"]]
    end
  end

  describe "cast/1" do
    test "accepts Gradient struct" do
      grad = Gradient.linear({0, 0}, {1, 1}, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])
      assert {:ok, ^grad} = Gradient.cast(grad)
    end

    test "accepts valid map with from/to" do
      assert {:ok, %Gradient{from: {0, 0}, to: {100, 100}}} =
               Gradient.cast(%{
                 from: {0, 0},
                 to: {100, 100},
                 stops: [{0.0, "#ff0000"}]
               })
    end

    test "rejects invalid input" do
      assert :error = Gradient.cast("not a gradient")
      assert :error = Gradient.cast(42)
    end
  end
end
