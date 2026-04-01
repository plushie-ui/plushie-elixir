defmodule Plushie.Animation.EasingTest do
  use ExUnit.Case, async: true

  alias Plushie.Animation.Easing

  # ---------------------------------------------------------------------------
  # Boundary conditions: every easing function must satisfy f(0) == 0, f(1) == 1
  # ---------------------------------------------------------------------------

  describe "boundary conditions" do
    for easing <- Easing.named_easings() do
      test "#{easing}(0) == 0 and #{easing}(1) == 1" do
        assert_in_delta apply(Easing, unquote(easing), [0.0]), 0.0, 1.0e-6
        assert_in_delta apply(Easing, unquote(easing), [1.0]), 1.0, 1.0e-6
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Monotonicity: ease_in curves should be <= linear, ease_out >= linear at 0.5
  # (except back/elastic/bounce which overshoot)
  # ---------------------------------------------------------------------------

  describe "midpoint behavior" do
    test "linear at 0.5 is 0.5" do
      assert_in_delta Easing.linear(0.5), 0.5, 1.0e-6
    end

    test "ease_in at 0.5 is less than 0.5 (slow start)" do
      assert Easing.ease_in(0.5) < 0.5
    end

    test "ease_out at 0.5 is greater than 0.5 (fast start)" do
      assert Easing.ease_out(0.5) > 0.5
    end

    test "ease_in_out at 0.5 is approximately 0.5 (symmetric)" do
      assert_in_delta Easing.ease_in_out(0.5), 0.5, 1.0e-6
    end

    for suffix <- [:quad, :cubic, :quart, :quint, :expo, :circ] do
      test "ease_in_#{suffix} at 0.5 is less than 0.5" do
        fun = :"ease_in_#{unquote(suffix)}"
        assert apply(Easing, fun, [0.5]) < 0.5
      end

      test "ease_out_#{suffix} at 0.5 is greater than 0.5" do
        fun = :"ease_out_#{unquote(suffix)}"
        assert apply(Easing, fun, [0.5]) > 0.5
      end

      test "ease_in_out_#{suffix} at 0.5 is approximately 0.5" do
        fun = :"ease_in_out_#{unquote(suffix)}"
        assert_in_delta apply(Easing, fun, [0.5]), 0.5, 1.0e-6
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Back curves overshoot
  # ---------------------------------------------------------------------------

  describe "back overshoot" do
    test "ease_in_back goes negative near start" do
      assert Easing.ease_in_back(0.1) < 0.0
    end

    test "ease_out_back exceeds 1.0 near end" do
      assert Easing.ease_out_back(0.9) > 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # Elastic curves overshoot
  # ---------------------------------------------------------------------------

  describe "elastic overshoot" do
    test "ease_out_elastic exceeds 1.0 early" do
      # Elastic overshoots then settles
      values = for t <- 1..9, do: Easing.ease_out_elastic(t / 10.0)
      assert Enum.any?(values, &(&1 > 1.0))
    end
  end

  # ---------------------------------------------------------------------------
  # Bounce curves stay in 0..1
  # ---------------------------------------------------------------------------

  describe "bounce range" do
    test "ease_out_bounce stays in 0..1" do
      for i <- 0..100 do
        t = i / 100.0
        v = Easing.ease_out_bounce(t)
        assert v >= 0.0 and v <= 1.0, "ease_out_bounce(#{t}) = #{v}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Cubic bezier
  # ---------------------------------------------------------------------------

  describe "cubic_bezier" do
    test "linear bezier matches linear easing" do
      # cubic-bezier(0, 0, 1, 1) is linear
      for i <- 0..10 do
        t = i / 10.0
        assert_in_delta Easing.cubic_bezier(t, 0.0, 0.0, 1.0, 1.0), t, 0.01
      end
    end

    test "ease bezier approximates ease_in_out" do
      # CSS ease: cubic-bezier(0.25, 0.1, 0.25, 1.0)
      v = Easing.cubic_bezier(0.5, 0.25, 0.1, 0.25, 1.0)
      assert v > 0.5, "CSS ease at 0.5 should be > 0.5 (fast middle)"
    end

    test "boundary: t=0 returns 0, t=1 returns 1" do
      assert_in_delta Easing.cubic_bezier(0.0, 0.42, 0.0, 0.58, 1.0), 0.0, 1.0e-6
      assert_in_delta Easing.cubic_bezier(1.0, 0.42, 0.0, 0.58, 1.0), 1.0, 1.0e-6
    end
  end

  # ---------------------------------------------------------------------------
  # valid?/1
  # ---------------------------------------------------------------------------

  describe "valid?/1" do
    test "accepts all named easings" do
      for easing <- Easing.named_easings() do
        assert Easing.valid?(easing), "#{easing} should be valid"
      end
    end

    test "accepts cubic bezier tuple" do
      assert Easing.valid?({:cubic_bezier, 0.25, 0.1, 0.25, 1.0})
    end

    test "rejects invalid atoms" do
      refute Easing.valid?(:nonexistent)
      refute Easing.valid?(:ease)
    end

    test "rejects non-easing terms" do
      refute Easing.valid?(42)
      refute Easing.valid?("ease_in")
      refute Easing.valid?(nil)
    end
  end

  # ---------------------------------------------------------------------------
  # name/1
  # ---------------------------------------------------------------------------

  describe "name/1" do
    test "named easings return their string form" do
      assert Easing.name(:linear) == "linear"
      assert Easing.name(:ease_in_out) == "ease_in_out"
      assert Easing.name(:ease_out_bounce) == "ease_out_bounce"
    end

    test "cubic bezier returns a map" do
      assert Easing.name({:cubic_bezier, 0.25, 0.1, 0.25, 1.0}) ==
               %{"cubic_bezier" => [0.25, 0.1, 0.25, 1.0]}
    end
  end

  # ---------------------------------------------------------------------------
  # function/1
  # ---------------------------------------------------------------------------

  describe "function/1" do
    test "returns a callable function" do
      f = Easing.function(:ease_in)
      assert is_function(f, 1)
      assert_in_delta f.(0.0), 0.0, 1.0e-6
      assert_in_delta f.(1.0), 1.0, 1.0e-6
    end

    test "cubic bezier function works" do
      f = Easing.function({:cubic_bezier, 0.0, 0.0, 1.0, 1.0})
      assert is_function(f, 1)
      assert_in_delta f.(0.5), 0.5, 0.01
    end
  end

  # ---------------------------------------------------------------------------
  # interpolate/4
  # ---------------------------------------------------------------------------

  describe "interpolate/4" do
    test "linear interpolation at midpoint" do
      assert_in_delta Easing.interpolate(0.0, 100.0, 0.5, :linear), 50.0, 1.0e-6
    end

    test "interpolation clamps t to 0..1" do
      assert_in_delta Easing.interpolate(0.0, 100.0, -0.5, :linear), 0.0, 1.0e-6
      assert_in_delta Easing.interpolate(0.0, 100.0, 1.5, :linear), 100.0, 1.0e-6
    end

    test "interpolation with easing" do
      # ease_in at 0.5 produces less than 0.5, so value < 50
      v = Easing.interpolate(0.0, 100.0, 0.5, :ease_in)
      assert v < 50.0
    end

    test "negative range" do
      assert_in_delta Easing.interpolate(100.0, 0.0, 0.5, :linear), 50.0, 1.0e-6
    end
  end
end
