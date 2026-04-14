defmodule Plushie.Canvas.AngleTest do
  use ExUnit.Case, async: true

  alias Plushie.Canvas.Angle

  describe "to_radians/1" do
    test "converts bare number (degrees) to radians" do
      assert_in_delta Angle.to_radians(180), :math.pi(), 0.0001
    end

    test "converts zero degrees to zero radians" do
      assert Angle.to_radians(0) == 0.0
    end

    test "converts 90 degrees to pi/2 radians" do
      assert_in_delta Angle.to_radians(90), :math.pi() / 2, 0.0001
    end

    test "converts 360 degrees to 2*pi radians" do
      assert_in_delta Angle.to_radians(360), 2 * :math.pi(), 0.0001
    end

    test "converts negative degrees" do
      assert_in_delta Angle.to_radians(-90), -:math.pi() / 2, 0.0001
    end

    test "accepts explicit degree tuple" do
      assert_in_delta Angle.to_radians({45, :deg}), :math.pi() / 4, 0.0001
    end

    test "passes through explicit radian tuple" do
      assert_in_delta Angle.to_radians({:math.pi(), :rad}), :math.pi(), 0.0001
    end

    test "radian tuple with zero" do
      assert Angle.to_radians({0, :rad}) == 0.0
    end
  end

  describe "to_degrees/1" do
    test "passes through bare number (already degrees)" do
      assert Angle.to_degrees(45) == 45.0
    end

    test "passes through degree tuple" do
      assert Angle.to_degrees({90, :deg}) == 90.0
    end

    test "converts radian tuple to degrees" do
      assert_in_delta Angle.to_degrees({:math.pi(), :rad}), 180.0, 0.0001
    end
  end

  describe "cast/1" do
    test "casts bare number to degrees" do
      assert {:ok, deg} = Angle.cast(180)
      assert_in_delta deg, 180.0, 0.0001
    end

    test "casts degree tuple to degrees" do
      assert {:ok, deg} = Angle.cast({90, :deg})
      assert_in_delta deg, 90.0, 0.0001
    end

    test "casts radian tuple to degrees" do
      assert {:ok, deg} = Angle.cast({:math.pi(), :rad})
      assert_in_delta deg, 180.0, 0.0001
    end

    test "rejects non-numeric values" do
      assert :error = Angle.cast("45")
      assert :error = Angle.cast(:degrees)
    end
  end
end
