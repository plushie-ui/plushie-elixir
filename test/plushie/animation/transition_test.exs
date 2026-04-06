defmodule Plushie.Animation.TransitionTest do
  use ExUnit.Case, async: true

  alias Plushie.Animation.Transition

  describe "new/1" do
    test "creates transition with required fields" do
      t = Transition.new(to: 0.0, duration: 300)
      assert t.to == 0.0
      assert t.duration == 300
      assert t.easing == :ease_in_out
      assert t.delay == 0
      assert t.from == nil
      assert t.repeat == nil
      assert t.auto_reverse == false
      assert t.on_complete == nil
    end

    test "accepts all options" do
      t =
        Transition.new(
          to: 0.5,
          duration: 500,
          easing: :ease_out,
          delay: 100,
          from: 1.0,
          repeat: 3,
          auto_reverse: true,
          on_complete: :done
        )

      assert t.to == 0.5
      assert t.duration == 500
      assert t.easing == :ease_out
      assert t.delay == 100
      assert t.from == 1.0
      assert t.repeat == 3
      assert t.auto_reverse == true
      assert t.on_complete == :done
    end

    test "raises without to:" do
      assert_raise ArgumentError, ~r/requires to:/, fn ->
        Transition.new(duration: 300)
      end
    end

    test "raises without duration:" do
      assert_raise ArgumentError, ~r/requires duration:/, fn ->
        Transition.new(to: 0.0)
      end
    end

    test "raises with non-positive duration" do
      assert_raise ArgumentError, ~r/positive integer/, fn ->
        Transition.new(to: 0.0, duration: 0)
      end
    end

    test "accepts cubic bezier easing" do
      t = Transition.new(to: 0.0, duration: 300, easing: {:cubic_bezier, 0.25, 0.1, 0.25, 1.0})
      assert t.easing == {:cubic_bezier, 0.25, 0.1, 0.25, 1.0}
    end

    test "raises with invalid easing" do
      assert_raise ArgumentError, ~r/invalid easing/, fn ->
        Transition.new(to: 0.0, duration: 300, easing: :nonexistent)
      end
    end

    test "raises with unknown option" do
      assert_raise ArgumentError, ~r/unknown transition option/, fn ->
        Transition.new(to: 0.0, duration: 300, bogus: true)
      end
    end

    test "cycles: aliases repeat:" do
      t = Transition.new(to: 0.0, duration: 300, cycles: 5)
      assert t.repeat == 5
    end
  end

  describe "new/2" do
    test "duration as first arg" do
      t = Transition.new(300, to: 0.0)
      assert t.duration == 300
      assert t.to == 0.0
    end

    test "duration with extra opts" do
      t = Transition.new(300, to: 0.0, easing: :ease_out, delay: 50)
      assert t.duration == 300
      assert t.easing == :ease_out
      assert t.delay == 50
    end
  end

  describe "loop/1" do
    test "sets repeat and auto_reverse defaults" do
      t = Transition.loop(to: 0.4, from: 1.0, duration: 800)
      assert t.repeat == :forever
      assert t.auto_reverse == true
      assert t.to == 0.4
      assert t.from == 1.0
      assert t.duration == 800
    end

    test "cycles: overrides repeat:" do
      t = Transition.loop(to: 0.4, from: 1.0, duration: 800, cycles: 3)
      assert t.repeat == 3
    end

    test "reverse: false overrides auto_reverse" do
      t = Transition.loop(to: 360, from: 0, duration: 1000, auto_reverse: false)
      assert t.auto_reverse == false
    end

    test "raises without from:" do
      assert_raise ArgumentError, ~r/loop requires from:/, fn ->
        Transition.loop(to: 0.4, duration: 800)
      end
    end
  end

  describe "loop/2" do
    test "duration as first arg" do
      t = Transition.loop(800, to: 0.4, from: 1.0)
      assert t.duration == 800
      assert t.repeat == :forever
    end
  end

  describe "pipeline" do
    test "chain setters" do
      t =
        Transition.new(300, to: 0.0)
        |> Transition.easing(:ease_out)
        |> Transition.delay(100)
        |> Transition.from(1.0)
        |> Transition.repeat(:forever)
        |> Transition.auto_reverse(true)
        |> Transition.on_complete(:done)

      assert t.easing == :ease_out
      assert t.delay == 100
      assert t.from == 1.0
      assert t.repeat == :forever
      assert t.auto_reverse == true
      assert t.on_complete == :done
    end
  end

  describe "encode" do
    test "minimal transition encodes type, to, duration" do
      t = Transition.new(300, to: 0.0)
      encoded = Transition.encode(t)

      assert encoded["type"] == "transition"
      assert encoded["to"] == 0.0
      assert encoded["duration"] == 300
      refute Map.has_key?(encoded, "easing")
      refute Map.has_key?(encoded, "delay")
      refute Map.has_key?(encoded, "from")
    end

    test "non-default fields are included" do
      t = Transition.new(300, to: 0.0, easing: :ease_out, delay: 100, from: 1.0)
      encoded = Transition.encode(t)

      assert encoded["easing"] == "ease_out"
      assert encoded["delay"] == 100
      assert encoded["from"] == 1.0
    end

    test "repeat forever encodes as -1" do
      t = Transition.new(300, to: 0.0, repeat: :forever)
      encoded = Transition.encode(t)
      assert encoded["repeat"] == -1
    end

    test "repeat count encodes as integer" do
      t = Transition.new(300, to: 0.0, repeat: 3)
      encoded = Transition.encode(t)
      assert encoded["repeat"] == 3
    end

    test "on_complete encodes as string" do
      t = Transition.new(300, to: 0.0, on_complete: :faded)
      encoded = Transition.encode(t)
      assert encoded["on_complete"] == "faded"
    end

    test "cubic bezier easing encodes as map" do
      t = Transition.new(300, to: 0.0, easing: {:cubic_bezier, 0.25, 0.1, 0.25, 1.0})
      encoded = Transition.encode(t)
      assert encoded["easing"] == %{"cubic_bezier" => [0.25, 0.1, 0.25, 1.0]}
    end

    test "loop encodes with repeat and auto_reverse" do
      t = Transition.loop(800, to: 0.4, from: 1.0)
      encoded = Transition.encode(t)

      assert encoded["repeat"] == -1
      assert encoded["auto_reverse"] == true
      assert encoded["from"] == 1.0
    end
  end

  describe "from_opts/1" do
    test "from_opts/1 builds a transition" do
      t = Transition.from_opts(to: 0.0, duration: 300, easing: :ease_out)
      assert t.to == 0.0
      assert t.duration == 300
      assert t.easing == :ease_out
    end

    test "__field_keys__/0 returns known keys" do
      keys = Transition.__field_keys__()
      assert :to in keys
      assert :duration in keys
      assert :easing in keys
    end
  end
end
