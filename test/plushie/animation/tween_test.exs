defmodule Plushie.Animation.TweenTest do
  use ExUnit.Case, async: true

  alias Plushie.Animation.Tween

  describe "new/1" do
    test "creates animation with required fields" do
      anim = Tween.new(from: 0.0, to: 1.0, duration: 300)
      assert anim.from == 0.0
      assert anim.to == 1.0
      assert anim.duration == 300
      assert anim.easing == :ease_in_out
      assert anim.value == 0.0
      assert anim.finished == false
      assert anim.started_at == nil
    end

    test "accepts easing option" do
      anim = Tween.new(from: 0.0, to: 1.0, duration: 300, easing: :ease_out)
      assert anim.easing == :ease_out
    end

    test "accepts delay option" do
      anim = Tween.new(from: 0.0, to: 1.0, duration: 300, delay: 100)
      assert anim.delay == 100
    end

    test "accepts repeat and auto_reverse" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 300, repeat: :forever, auto_reverse: true)

      assert anim.repeat == :forever
      assert anim.auto_reverse == true
    end

    test "raises without required fields" do
      assert_raise KeyError, fn -> Tween.new(to: 1.0, duration: 300) end
      assert_raise KeyError, fn -> Tween.new(from: 0.0, duration: 300) end
      assert_raise KeyError, fn -> Tween.new(from: 0.0, to: 1.0) end
    end

    test "raises with invalid easing" do
      assert_raise ArgumentError, fn ->
        Tween.new(from: 0.0, to: 1.0, duration: 300, easing: :nonexistent)
      end
    end

    test "raises with non-numeric endpoints" do
      assert_raise ArgumentError, ~r/expected from to be a number/, fn ->
        Tween.new(from: "start", to: 1.0, duration: 300)
      end

      assert_raise ArgumentError, ~r/expected to to be a number/, fn ->
        Tween.new(from: 0.0, to: "end", duration: 300)
      end
    end

    test "raises with invalid duration and delay" do
      assert_raise ArgumentError, ~r/expected duration to be a positive integer/, fn ->
        Tween.new(from: 0.0, to: 1.0, duration: 0)
      end

      assert_raise ArgumentError, ~r/expected delay to be a non-negative integer/, fn ->
        Tween.new(from: 0.0, to: 1.0, duration: 300, delay: -1)
      end
    end
  end

  describe "looping/4" do
    test "creates a forever auto-reversing tween" do
      anim = Tween.looping(0.0, 1.0, 500, easing: :linear)

      assert anim.from == 0.0
      assert anim.to == 1.0
      assert anim.duration == 500
      assert anim.repeat == :forever
      assert anim.auto_reverse == true
      assert anim.easing == :linear
    end

    test "validates duration through new/1" do
      assert_raise ArgumentError, ~r/expected duration to be a positive integer/, fn ->
        Tween.looping(0.0, 1.0, 0)
      end
    end
  end

  describe "spring/1" do
    test "creates spring animation" do
      anim = Tween.spring(from: 0.0, to: 1.0)
      assert anim.from == 0.0
      assert anim.to == 1.0
      assert anim.spring_config.stiffness == 100
      assert anim.spring_config.damping == 10
      assert anim.spring_config.mass == 1.0
      assert anim.spring_config.velocity == 0.0
    end

    test "accepts custom spring parameters" do
      anim = Tween.spring(from: 0.0, to: 1.0, stiffness: 200, damping: 20)
      assert anim.spring_config.stiffness == 200
      assert anim.spring_config.damping == 20
    end

    test "rejects invalid mass values" do
      assert_raise ArgumentError, ~r/expected mass to be a positive number/, fn ->
        Tween.spring(from: 0.0, to: 1.0, mass: 0)
      end

      assert_raise ArgumentError, ~r/expected mass to be a positive number/, fn ->
        Tween.spring(from: 0.0, to: 1.0, mass: -1)
      end
    end

    test "rejects non-numeric endpoints and spring parameters" do
      assert_raise ArgumentError, ~r/expected to to be a number/, fn ->
        Tween.spring(from: 0.0, to: "end")
      end

      assert_raise ArgumentError, ~r/expected stiffness to be a positive number/, fn ->
        Tween.spring(from: 0.0, to: 1.0, stiffness: 0)
      end

      assert_raise ArgumentError, ~r/expected damping to be a non-negative number/, fn ->
        Tween.spring(from: 0.0, to: 1.0, damping: -1)
      end
    end
  end

  describe "start/2" do
    test "sets started_at and resets value" do
      anim = Tween.new(from: 0.0, to: 1.0, duration: 300) |> Tween.start(1000)
      assert anim.started_at == 1000
      assert anim.value == 0.0
      assert anim.finished == false
    end

    test "restart resets to from" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 300, easing: :linear)
        |> Tween.start(1000)
        |> Tween.advance(1150)
        |> Tween.start(2000)

      assert anim.started_at == 2000
      assert anim.value == 0.0
    end
  end

  describe "start_once/2" do
    test "starts if not started" do
      anim = Tween.new(from: 0.0, to: 1.0, duration: 300) |> Tween.start_once(1000)
      assert anim.started_at == 1000
    end

    test "no-op if already started" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 300)
        |> Tween.start(1000)
        |> Tween.start_once(2000)

      assert anim.started_at == 1000
    end
  end

  describe "advance/2 (timed)" do
    test "returns struct unchanged if not started" do
      anim = Tween.new(from: 0.0, to: 1.0, duration: 300)
      assert Tween.advance(anim, 5000) == anim
    end

    test "interpolates at midpoint" do
      anim =
        Tween.new(from: 0.0, to: 100.0, duration: 200, easing: :linear)
        |> Tween.start(1000)
        |> Tween.advance(1100)

      assert_in_delta Tween.value(anim), 50.0, 0.5
    end

    test "finishes at or past duration" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 300, easing: :linear)
        |> Tween.start(1000)
        |> Tween.advance(1300)

      assert Tween.finished?(anim)
      assert Tween.value(anim) == 1.0
    end

    test "stays finished after completion" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 100, easing: :linear)
        |> Tween.start(0)
        |> Tween.advance(200)

      assert Tween.finished?(anim)
      anim2 = Tween.advance(anim, 300)
      assert Tween.finished?(anim2)
    end

    test "respects delay" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 200, delay: 100, easing: :linear)
        |> Tween.start(1000)

      # During delay: value stays at from
      anim_during = Tween.advance(anim, 1050)
      assert Tween.value(anim_during) == 0.0

      # After delay: animation starts
      anim_after = Tween.advance(anim, 1200)
      assert_in_delta Tween.value(anim_after), 0.5, 0.1
    end

    test "applies easing" do
      anim_linear =
        Tween.new(from: 0.0, to: 1.0, duration: 200, easing: :linear)
        |> Tween.start(0)
        |> Tween.advance(100)

      anim_ease_in =
        Tween.new(from: 0.0, to: 1.0, duration: 200, easing: :ease_in)
        |> Tween.start(0)
        |> Tween.advance(100)

      # ease_in at midpoint should be less than linear
      assert Tween.value(anim_ease_in) < Tween.value(anim_linear)
    end

    test "negative range (downward animation)" do
      anim =
        Tween.new(from: 100.0, to: 0.0, duration: 200, easing: :linear)
        |> Tween.start(0)
        |> Tween.advance(100)

      assert_in_delta Tween.value(anim), 50.0, 0.5
    end
  end

  describe "advance/2 (repeat)" do
    test "repeats forever" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 100, easing: :linear, repeat: :forever)
        |> Tween.start(0)
        |> Tween.advance(100)

      refute Tween.finished?(anim)
    end

    test "finite repeat counts down" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 100, easing: :linear, repeat: 2)
        |> Tween.start(0)
        |> Tween.advance(100)

      refute Tween.finished?(anim)
    end

    test "auto_reverse swaps from/to" do
      anim =
        Tween.new(
          from: 0.0,
          to: 1.0,
          duration: 100,
          easing: :linear,
          repeat: :forever,
          auto_reverse: true
        )
        |> Tween.start(0)
        |> Tween.advance(100)

      assert anim.from == 1.0
      assert anim.to == 0.0
    end
  end

  describe "advance/2 (spring)" do
    test "spring approaches target" do
      anim =
        Tween.spring(from: 0.0, to: 1.0, stiffness: 200, damping: 20)
        |> Tween.start(0)
        |> Tween.advance(500)

      assert_in_delta Tween.value(anim), 1.0, 0.1
    end

    test "spring settles and finishes" do
      anim =
        Tween.spring(from: 0.0, to: 1.0, stiffness: 200, damping: 20)
        |> Tween.start(0)
        |> Tween.advance(2000)

      assert Tween.finished?(anim)
      assert_in_delta Tween.value(anim), 1.0, 0.001
    end

    test "zero delta does not advance spring state" do
      anim = Tween.spring(from: 0.0, to: 1.0, stiffness: 200, damping: 20) |> Tween.start(100)

      assert Tween.advance(anim, 100) == anim
    end
  end

  describe "redirect/2" do
    test "changes target from current position" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 200, easing: :linear)
        |> Tween.start(0)
        |> Tween.advance(100)

      anim = Tween.redirect(anim, to: 0.0, at: 100)
      assert anim.to == 0.0
      assert_in_delta anim.from, 0.5, 0.1
      assert anim.started_at == 100
      refute Tween.finished?(anim)
    end

    test "can change duration on redirect" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 200, easing: :linear)
        |> Tween.start(0)
        |> Tween.advance(100)
        |> Tween.redirect(to: 0.0, at: 100, duration: 400)

      assert anim.duration == 400
    end

    test "spring redirect preserves velocity" do
      anim =
        Tween.spring(from: 0.0, to: 100.0, stiffness: 400, damping: 30)
        |> Tween.start(0)
        |> Tween.advance(50)

      velocity_before = anim.spring_config.velocity
      value_before = Tween.value(anim)

      redirected = Tween.redirect(anim, to: 200.0, at: 50)

      assert redirected.from == value_before
      assert redirected.to == 200.0
      assert redirected.spring_config.velocity == velocity_before
    end

    test "validates redirect target and timestamp" do
      anim = Tween.new(from: 0.0, to: 1.0, duration: 200)

      assert_raise ArgumentError, ~r/expected to to be a number/, fn ->
        Tween.redirect(anim, to: "end", at: 100)
      end

      assert_raise ArgumentError, ~r/expected :at to be an integer timestamp/, fn ->
        Tween.redirect(anim, to: 0.0, at: "now")
      end
    end
  end

  describe "queries" do
    test "value returns current value" do
      anim = Tween.new(from: 5.0, to: 10.0, duration: 100)
      assert Tween.value(anim) == 5.0
    end

    test "finished? is false initially" do
      anim = Tween.new(from: 0.0, to: 1.0, duration: 100)
      refute Tween.finished?(anim)
    end

    test "running? is false before start" do
      anim = Tween.new(from: 0.0, to: 1.0, duration: 100)
      refute Tween.running?(anim)
    end

    test "running? is true during animation" do
      anim = Tween.new(from: 0.0, to: 1.0, duration: 100) |> Tween.start(0)
      assert Tween.running?(anim)
    end

    test "running? is false after finish" do
      anim =
        Tween.new(from: 0.0, to: 1.0, duration: 100, easing: :linear)
        |> Tween.start(0)
        |> Tween.advance(200)

      refute Tween.running?(anim)
    end
  end
end
