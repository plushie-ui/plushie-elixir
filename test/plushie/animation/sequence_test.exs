defmodule Plushie.Animation.SequenceTest do
  use ExUnit.Case, async: true

  alias Plushie.Animation.{Sequence, Spring, Transition}

  describe "new/1" do
    test "creates sequence from transition list" do
      s =
        Sequence.new([
          Transition.new(200, to: 1.0, from: 0.0),
          Transition.new(300, to: 0.0)
        ])

      assert length(s.steps) == 2
      assert s.on_complete == nil
    end

    test "creates sequence with spring steps" do
      s =
        Sequence.new([
          Transition.new(200, to: 1.0, from: 0.0),
          Spring.new(to: 0.5, preset: :bouncy)
        ])

      assert length(s.steps) == 2
    end

    test "accepts on_complete option" do
      s =
        Sequence.new(
          [Transition.new(200, to: 1.0, from: 0.0)],
          on_complete: :done
        )

      assert s.on_complete == :done
    end

    test "raises with empty steps" do
      assert_raise ArgumentError, ~r/at least one step/, fn ->
        Sequence.new([])
      end
    end

    test "raises with invalid step type" do
      assert_raise ArgumentError, ~r/must be Transition or Spring/, fn ->
        Sequence.new([%{not: "a transition"}])
      end
    end
  end

  describe "on_complete/2" do
    test "sets completion tag" do
      s =
        Sequence.new([Transition.new(200, to: 1.0, from: 0.0)])
        |> Sequence.on_complete(:done)

      assert s.on_complete == :done
    end
  end

  describe "encode" do
    test "encodes with type and steps" do
      s =
        Sequence.new([
          Transition.new(200, to: 1.0, from: 0.0),
          Transition.new(300, to: 0.0)
        ])

      encoded = Plushie.Encode.encode(s)

      assert encoded["type"] == "sequence"
      assert length(encoded["steps"]) == 2
      assert hd(encoded["steps"])["type"] == "transition"
      refute Map.has_key?(encoded, "on_complete")
    end

    test "includes on_complete when set" do
      s =
        Sequence.new(
          [Transition.new(200, to: 1.0, from: 0.0)],
          on_complete: :done
        )

      encoded = Plushie.Encode.encode(s)
      assert encoded["on_complete"] == "done"
    end

    test "encodes mixed transition and spring steps" do
      s =
        Sequence.new([
          Transition.new(200, to: 1.0, from: 0.0),
          Spring.new(to: 0.5, preset: :bouncy)
        ])

      encoded = Plushie.Encode.encode(s)
      steps = encoded["steps"]
      assert Enum.at(steps, 0)["type"] == "transition"
      assert Enum.at(steps, 1)["type"] == "spring"
    end

    test "loop step encodes correctly in sequence" do
      s =
        Sequence.new([
          Transition.new(200, to: 1.0, from: 0.0),
          Transition.loop(800, to: 0.7, from: 1.0, cycles: 3),
          Transition.new(300, to: 0.0)
        ])

      encoded = Plushie.Encode.encode(s)
      loop_step = Enum.at(encoded["steps"], 1)
      assert loop_step["repeat"] == 3
      assert loop_step["auto_reverse"] == true
    end
  end
end
