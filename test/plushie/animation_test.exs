defmodule Plushie.AnimationTest do
  use ExUnit.Case, async: true

  alias Plushie.Animation

  # ---------------------------------------------------------------------------
  # new/1
  # ---------------------------------------------------------------------------

  describe "new/1" do
    test "creates animation with required fields" do
      anim = Animation.new(from: 0.0, to: 1.0, duration: 300)
      assert anim.from == 0.0
      assert anim.to == 1.0
      assert anim.duration == 300
      assert anim.easing == :ease_in_out
      assert anim.value == 0.0
      assert anim.finished == false
      assert anim.started_at == nil
    end

    test "accepts easing option" do
      anim = Animation.new(from: 0.0, to: 1.0, duration: 300, easing: :ease_out)
      assert anim.easing == :ease_out
    end

    test "accepts delay option" do
      anim = Animation.new(from: 0.0, to: 1.0, duration: 300, delay: 100)
      assert anim.delay == 100
    end

    test "accepts repeat and auto_reverse" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 300, repeat: :forever, auto_reverse: true)

      assert anim.repeat == :forever
      assert anim.auto_reverse == true
    end

    test "raises without required fields" do
      assert_raise KeyError, fn -> Animation.new(to: 1.0, duration: 300) end
      assert_raise KeyError, fn -> Animation.new(from: 0.0, duration: 300) end
      assert_raise KeyError, fn -> Animation.new(from: 0.0, to: 1.0) end
    end

    test "raises with invalid easing" do
      assert_raise ArgumentError, fn ->
        Animation.new(from: 0.0, to: 1.0, duration: 300, easing: :nonexistent)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # spring/1
  # ---------------------------------------------------------------------------

  describe "spring/1" do
    test "creates spring animation" do
      anim = Animation.spring(from: 0.0, to: 1.0)
      assert anim.from == 0.0
      assert anim.to == 1.0
      assert anim.spring_config.stiffness == 100
      assert anim.spring_config.damping == 10
      assert anim.spring_config.mass == 1.0
      assert anim.spring_config.velocity == 0.0
    end

    test "accepts custom spring parameters" do
      anim = Animation.spring(from: 0.0, to: 1.0, stiffness: 200, damping: 20)
      assert anim.spring_config.stiffness == 200
      assert anim.spring_config.damping == 20
    end
  end

  # ---------------------------------------------------------------------------
  # start/2 and start_once/2
  # ---------------------------------------------------------------------------

  describe "start/2" do
    test "sets started_at and resets value" do
      anim = Animation.new(from: 0.0, to: 1.0, duration: 300) |> Animation.start(1000)
      assert anim.started_at == 1000
      assert anim.value == 0.0
      assert anim.finished == false
    end

    test "restart resets to from" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 300, easing: :linear)
        |> Animation.start(1000)
        |> Animation.advance(1150)
        |> Animation.start(2000)

      assert anim.started_at == 2000
      assert anim.value == 0.0
    end
  end

  describe "start_once/2" do
    test "starts if not started" do
      anim = Animation.new(from: 0.0, to: 1.0, duration: 300) |> Animation.start_once(1000)
      assert anim.started_at == 1000
    end

    test "no-op if already started" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 300)
        |> Animation.start(1000)
        |> Animation.start_once(2000)

      assert anim.started_at == 1000
    end
  end

  # ---------------------------------------------------------------------------
  # advance/2 (timed)
  # ---------------------------------------------------------------------------

  describe "advance/2 (timed)" do
    test "returns struct unchanged if not started" do
      anim = Animation.new(from: 0.0, to: 1.0, duration: 300)
      assert Animation.advance(anim, 5000) == anim
    end

    test "interpolates at midpoint" do
      anim =
        Animation.new(from: 0.0, to: 100.0, duration: 200, easing: :linear)
        |> Animation.start(1000)
        |> Animation.advance(1100)

      assert_in_delta Animation.value(anim), 50.0, 0.5
    end

    test "finishes at or past duration" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 300, easing: :linear)
        |> Animation.start(1000)
        |> Animation.advance(1300)

      assert Animation.finished?(anim)
      assert Animation.value(anim) == 1.0
    end

    test "stays finished after completion" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 100, easing: :linear)
        |> Animation.start(0)
        |> Animation.advance(200)

      assert Animation.finished?(anim)
      anim2 = Animation.advance(anim, 300)
      assert Animation.finished?(anim2)
    end

    test "respects delay" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 200, delay: 100, easing: :linear)
        |> Animation.start(1000)

      # During delay: value stays at from
      anim_during = Animation.advance(anim, 1050)
      assert Animation.value(anim_during) == 0.0

      # After delay: animation starts
      anim_after = Animation.advance(anim, 1200)
      assert_in_delta Animation.value(anim_after), 0.5, 0.1
    end

    test "applies easing" do
      anim_linear =
        Animation.new(from: 0.0, to: 1.0, duration: 200, easing: :linear)
        |> Animation.start(0)
        |> Animation.advance(100)

      anim_ease_in =
        Animation.new(from: 0.0, to: 1.0, duration: 200, easing: :ease_in)
        |> Animation.start(0)
        |> Animation.advance(100)

      # ease_in at midpoint should be less than linear
      assert Animation.value(anim_ease_in) < Animation.value(anim_linear)
    end

    test "negative range (downward animation)" do
      anim =
        Animation.new(from: 100.0, to: 0.0, duration: 200, easing: :linear)
        |> Animation.start(0)
        |> Animation.advance(100)

      assert_in_delta Animation.value(anim), 50.0, 0.5
    end
  end

  # ---------------------------------------------------------------------------
  # advance/2 (repeat)
  # ---------------------------------------------------------------------------

  describe "advance/2 (repeat)" do
    test "repeats forever" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 100, easing: :linear, repeat: :forever)
        |> Animation.start(0)
        |> Animation.advance(100)

      refute Animation.finished?(anim)
    end

    test "finite repeat counts down" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 100, easing: :linear, repeat: 2)
        |> Animation.start(0)
        |> Animation.advance(100)

      refute Animation.finished?(anim)
    end

    test "auto_reverse swaps from/to" do
      anim =
        Animation.new(
          from: 0.0,
          to: 1.0,
          duration: 100,
          easing: :linear,
          repeat: :forever,
          auto_reverse: true
        )
        |> Animation.start(0)
        |> Animation.advance(100)

      assert anim.from == 1.0
      assert anim.to == 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # advance/2 (spring)
  # ---------------------------------------------------------------------------

  describe "advance/2 (spring)" do
    test "spring approaches target" do
      anim =
        Animation.spring(from: 0.0, to: 1.0, stiffness: 200, damping: 20)
        |> Animation.start(0)
        |> Animation.advance(500)

      assert_in_delta Animation.value(anim), 1.0, 0.1
    end

    test "spring settles and finishes" do
      anim =
        Animation.spring(from: 0.0, to: 1.0, stiffness: 200, damping: 20)
        |> Animation.start(0)
        |> Animation.advance(2000)

      assert Animation.finished?(anim)
      assert_in_delta Animation.value(anim), 1.0, 0.001
    end
  end

  # ---------------------------------------------------------------------------
  # redirect/2
  # ---------------------------------------------------------------------------

  describe "redirect/2" do
    test "changes target from current position" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 200, easing: :linear)
        |> Animation.start(0)
        |> Animation.advance(100)

      anim = Animation.redirect(anim, to: 0.0, at: 100)
      assert anim.to == 0.0
      assert_in_delta anim.from, 0.5, 0.1
      assert anim.started_at == 100
      refute Animation.finished?(anim)
    end

    test "can change duration on redirect" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 200, easing: :linear)
        |> Animation.start(0)
        |> Animation.advance(100)
        |> Animation.redirect(to: 0.0, at: 100, duration: 400)

      assert anim.duration == 400
    end
  end

  # ---------------------------------------------------------------------------
  # value/1, finished?/1, running?/1
  # ---------------------------------------------------------------------------

  describe "queries" do
    test "value returns current value" do
      anim = Animation.new(from: 5.0, to: 10.0, duration: 100)
      assert Animation.value(anim) == 5.0
    end

    test "finished? is false initially" do
      anim = Animation.new(from: 0.0, to: 1.0, duration: 100)
      refute Animation.finished?(anim)
    end

    test "running? is false before start" do
      anim = Animation.new(from: 0.0, to: 1.0, duration: 100)
      refute Animation.running?(anim)
    end

    test "running? is true during animation" do
      anim = Animation.new(from: 0.0, to: 1.0, duration: 100) |> Animation.start(0)
      assert Animation.running?(anim)
    end

    test "running? is false after finish" do
      anim =
        Animation.new(from: 0.0, to: 1.0, duration: 100, easing: :linear)
        |> Animation.start(0)
        |> Animation.advance(200)

      refute Animation.running?(anim)
    end
  end
end
