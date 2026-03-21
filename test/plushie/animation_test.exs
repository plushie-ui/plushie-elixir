defmodule Plushie.AnimationTest do
  use ExUnit.Case, async: true

  alias Plushie.Animation

  # -- Easing functions -------------------------------------------------------

  describe "linear/1" do
    test "identity at boundaries and midpoint" do
      assert Animation.linear(0.0) == 0.0
      assert Animation.linear(0.5) == 0.5
      assert Animation.linear(1.0) == 1.0
    end
  end

  describe "ease_in/1 (cubic)" do
    test "boundaries" do
      assert Animation.ease_in(0.0) == 0.0
      assert Animation.ease_in(1.0) == 1.0
    end

    test "midpoint is below linear (starts slow)" do
      mid = Animation.ease_in(0.5)
      assert mid == 0.125
      assert mid < 0.5
    end
  end

  describe "ease_out/1 (cubic)" do
    test "boundaries" do
      assert Animation.ease_out(0.0) == 0.0
      assert Animation.ease_out(1.0) == 1.0
    end

    test "midpoint is above linear (starts fast)" do
      mid = Animation.ease_out(0.5)
      assert mid == 0.875
      assert mid > 0.5
    end
  end

  describe "ease_in_out/1 (cubic)" do
    test "boundaries" do
      assert Animation.ease_in_out(0.0) == 0.0
      assert Animation.ease_in_out(1.0) == 1.0
    end

    test "midpoint is exactly 0.5" do
      assert Animation.ease_in_out(0.5) == 0.5
    end

    test "first half is below linear, second half is above" do
      assert Animation.ease_in_out(0.25) < 0.25
      assert Animation.ease_in_out(0.75) > 0.75
    end
  end

  describe "ease_in_quad/1" do
    test "boundaries" do
      assert Animation.ease_in_quad(0.0) == 0.0
      assert Animation.ease_in_quad(1.0) == 1.0
    end

    test "midpoint" do
      assert Animation.ease_in_quad(0.5) == 0.25
    end
  end

  describe "ease_out_quad/1" do
    test "boundaries" do
      assert Animation.ease_out_quad(0.0) == 0.0
      assert Animation.ease_out_quad(1.0) == 1.0
    end

    test "midpoint" do
      assert Animation.ease_out_quad(0.5) == 0.75
    end
  end

  describe "ease_in_out_quad/1" do
    test "boundaries" do
      assert Animation.ease_in_out_quad(0.0) == 0.0
      assert Animation.ease_in_out_quad(1.0) == 1.0
    end

    test "midpoint is exactly 0.5" do
      assert Animation.ease_in_out_quad(0.5) == 0.5
    end

    test "symmetry around midpoint" do
      lo = Animation.ease_in_out_quad(0.25)
      hi = Animation.ease_in_out_quad(0.75)
      assert_in_delta lo, 1.0 - hi, 1.0e-10
    end
  end

  describe "spring/1" do
    test "boundaries" do
      assert Animation.spring(0.0) == 0.0
      assert_in_delta Animation.spring(1.0), 1.0, 1.0e-3
    end

    test "overshoots past 1.0 during animation" do
      # Sample several points -- at least one should exceed 1.0
      samples = for i <- 1..9, do: Animation.spring(i / 10.0)
      assert Enum.any?(samples, &(&1 > 1.0))
    end
  end

  # -- Out-of-range t values ---------------------------------------------------

  describe "easing functions with out-of-range t" do
    # Verify that easing functions don't crash or produce non-numeric results
    # when given t values outside the expected 0.0..1.0 range.

    test "linear handles t < 0 and t > 1" do
      assert is_number(Animation.linear(-0.5))
      assert is_number(Animation.linear(1.5))
      assert Animation.linear(-0.5) == -0.5
      assert Animation.linear(1.5) == 1.5
    end

    test "ease_in handles t < 0 and t > 1" do
      assert is_number(Animation.ease_in(-0.5))
      assert is_number(Animation.ease_in(1.5))
      # ease_in is cubic: t^3, so -0.5^3 = -0.125
      assert_in_delta Animation.ease_in(-0.5), -0.125, 1.0e-10
    end

    test "ease_out handles t < 0 and t > 1" do
      assert is_number(Animation.ease_out(-0.5))
      assert is_number(Animation.ease_out(1.5))
    end

    test "ease_in_out handles t < 0 and t > 1" do
      assert is_number(Animation.ease_in_out(-0.5))
      assert is_number(Animation.ease_in_out(1.5))
    end

    test "ease_in_quad handles t < 0 and t > 1" do
      assert is_number(Animation.ease_in_quad(-0.5))
      assert is_number(Animation.ease_in_quad(1.5))
      # ease_in_quad is t^2, so (-0.5)^2 = 0.25
      assert_in_delta Animation.ease_in_quad(-0.5), 0.25, 1.0e-10
    end

    test "ease_out_quad handles t < 0 and t > 1" do
      assert is_number(Animation.ease_out_quad(-0.5))
      assert is_number(Animation.ease_out_quad(1.5))
    end

    test "spring handles t < 0 and t > 1" do
      assert is_number(Animation.spring(-0.5))
      assert is_number(Animation.spring(1.5))
    end
  end

  # -- Interpolation ----------------------------------------------------------

  describe "interpolate/4" do
    test "basic lerp without easing" do
      assert Animation.interpolate(0.0, 100.0, 0.0) == 0.0
      assert Animation.interpolate(0.0, 100.0, 0.5) == 50.0
      assert Animation.interpolate(0.0, 100.0, 1.0) == 100.0
    end

    test "lerp with non-zero start" do
      assert Animation.interpolate(10.0, 20.0, 0.5) == 15.0
    end

    test "lerp with easing function" do
      # ease_in_quad at t=0.5 -> 0.25, so result should be 25.0
      result = Animation.interpolate(0.0, 100.0, 0.5, &Animation.ease_in_quad/1)
      assert result == 25.0
    end

    test "clamps t below 0" do
      assert Animation.interpolate(0.0, 100.0, -0.5) == 0.0
    end

    test "clamps t above 1" do
      assert Animation.interpolate(0.0, 100.0, 1.5) == 100.0
    end

    test "works with negative ranges" do
      assert Animation.interpolate(100.0, 0.0, 0.5) == 50.0
    end
  end

  # -- Animation struct lifecycle ---------------------------------------------

  describe "new/4" do
    test "creates animation with defaults" do
      anim = Animation.new(0.0, 1.0, 300)
      assert anim.from == 0.0
      assert anim.to == 1.0
      assert anim.duration == 300
      assert anim.started_at == nil
      assert anim.value == 0.0
    end

    test "accepts easing option" do
      anim = Animation.new(0.0, 1.0, 300, easing: &Animation.ease_out/1)
      # Easing is a function, just verify it works
      assert anim.easing.(0.5) == Animation.ease_out(0.5)
    end
  end

  describe "start/2" do
    test "sets started_at and resets value to from" do
      anim = Animation.new(10.0, 20.0, 500)
      started = Animation.start(anim, 1000)
      assert started.started_at == 1000
      assert started.value == 10.0
    end

    test "restart resets to from" do
      anim =
        Animation.new(0.0, 1.0, 100)
        |> Animation.start(1000)

      # Simulate mid-animation
      {_val, anim} = Animation.advance(anim, 1050)
      assert anim.value != 0.0

      # Restart
      restarted = Animation.start(anim, 2000)
      assert restarted.started_at == 2000
      assert restarted.value == 0.0
    end
  end

  describe "advance/2" do
    test "returns from value if not started" do
      anim = Animation.new(5.0, 10.0, 100)
      {value, returned} = Animation.advance(anim, 1050)
      assert value == 5.0
      assert returned == anim
    end

    test "interpolates at midpoint" do
      anim =
        Animation.new(0.0, 100.0, 1000)
        |> Animation.start(1000)

      {value, updated} = Animation.advance(anim, 1500)
      assert value == 50.0
      assert updated.value == 50.0
    end

    test "returns :finished when duration elapsed" do
      anim =
        Animation.new(0.0, 100.0, 1000)
        |> Animation.start(1000)

      {value, status} = Animation.advance(anim, 2000)
      assert value == 100.0
      assert status == :finished
    end

    test "returns :finished when past duration" do
      anim =
        Animation.new(0.0, 100.0, 1000)
        |> Animation.start(1000)

      {value, status} = Animation.advance(anim, 3000)
      assert value == 100.0
      assert status == :finished
    end

    test "uses easing function" do
      anim =
        Animation.new(0.0, 100.0, 1000, easing: &Animation.ease_in_quad/1)
        |> Animation.start(1000)

      # At t=0.5, ease_in_quad gives 0.25, so value should be 25.0
      {value, _} = Animation.advance(anim, 1500)
      assert value == 25.0
    end

    test "clamps negative elapsed to start" do
      anim =
        Animation.new(0.0, 100.0, 1000)
        |> Animation.start(1000)

      # Timestamp before start -- should clamp to t=0
      {value, updated} = Animation.advance(anim, 500)
      assert value == 0.0
      assert updated.value == 0.0
    end

    test "sequential advances track progress" do
      anim =
        Animation.new(0.0, 100.0, 1000)
        |> Animation.start(0)

      {v1, anim} = Animation.advance(anim, 250)
      assert v1 == 25.0

      {v2, anim} = Animation.advance(anim, 500)
      assert v2 == 50.0

      {v3, _status} = Animation.advance(anim, 1000)
      assert v3 == 100.0
    end
  end

  describe "finished?/1" do
    test "false when not started" do
      anim = Animation.new(0.0, 1.0, 100)
      refute Animation.finished?(anim)
    end

    test "false mid-animation" do
      anim =
        Animation.new(0.0, 1.0, 1000)
        |> Animation.start(0)

      {_, anim} = Animation.advance(anim, 500)
      refute Animation.finished?(anim)
    end

    test "true after reaching target via manual value set" do
      # finished? checks value == to
      anim = %Animation{
        from: 0.0,
        to: 1.0,
        duration: 100,
        started_at: 0,
        easing: &Animation.linear/1,
        value: 1.0
      }

      assert Animation.finished?(anim)
    end
  end

  describe "value/1" do
    test "returns current value" do
      anim = Animation.new(42.0, 100.0, 500)
      assert Animation.value(anim) == 42.0
    end

    test "returns updated value after advance" do
      anim =
        Animation.new(0.0, 100.0, 1000)
        |> Animation.start(0)

      {_, anim} = Animation.advance(anim, 500)
      assert Animation.value(anim) == 50.0
    end
  end

  # -- Edge cases -------------------------------------------------------------

  describe "edge cases" do
    test "zero-from-to animation" do
      anim =
        Animation.new(5.0, 5.0, 100)
        |> Animation.start(0)

      {value, :finished} = Animation.advance(anim, 100)
      assert value == 5.0
    end

    test "very short duration" do
      anim =
        Animation.new(0.0, 1.0, 1)
        |> Animation.start(0)

      {value, :finished} = Animation.advance(anim, 1)
      assert value == 1.0
    end

    test "negative range (animating downward)" do
      anim =
        Animation.new(100.0, 0.0, 1000)
        |> Animation.start(0)

      {value, _} = Animation.advance(anim, 500)
      assert value == 50.0
    end
  end
end
