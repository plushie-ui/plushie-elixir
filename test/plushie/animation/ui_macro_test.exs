defmodule Plushie.Animation.UIMacroTest do
  use ExUnit.Case, async: true

  import Plushie.UI

  alias Plushie.Animation.{Sequence, Spring, Transition}

  # ---------------------------------------------------------------------------
  # transition macro
  # ---------------------------------------------------------------------------

  describe "transition macro" do
    test "keyword form with duration positional" do
      t = transition(300, to: 0.0)
      assert %Transition{to: 0.0, duration: 300} = t
    end

    test "keyword form with all options" do
      t = transition(300, to: 0.0, easing: :ease_out, delay: 100, from: 1.0)
      assert t.easing == :ease_out
      assert t.delay == 100
      assert t.from == 1.0
    end

    test "all-keyword form" do
      t = transition(to: 0.0, duration: 300)
      assert %Transition{to: 0.0, duration: 300} = t
    end

    test "do-block form with duration" do
      t =
        transition 300 do
          to(0.0)
          easing(:ease_out)
        end

      assert %Transition{to: 0.0, duration: 300, easing: :ease_out} = t
    end

    test "do-block form all keyword" do
      t =
        transition do
          to(0.0)
          duration(300)
          easing(:ease_out)
        end

      assert %Transition{to: 0.0, duration: 300, easing: :ease_out} = t
    end

    test "used as a prop value on container" do
      node =
        container "box", max_width: transition(300, to: 200) do
        end

      assert %Transition{to: 200, duration: 300} = node.props[:max_width]
    end
  end

  # ---------------------------------------------------------------------------
  # loop macro
  # ---------------------------------------------------------------------------

  describe "loop macro" do
    test "keyword form with duration positional" do
      t = loop(800, to: 0.4, from: 1.0)
      assert %Transition{to: 0.4, from: 1.0, duration: 800, repeat: :forever} = t
      assert t.auto_reverse == true
    end

    test "all-keyword form" do
      t = loop(to: 0.4, from: 1.0, duration: 800)
      assert t.repeat == :forever
    end

    test "with cycles" do
      t = loop(800, to: 0.4, from: 1.0, cycles: 3)
      assert t.repeat == 3
    end

    test "do-block form" do
      t =
        loop 800 do
          to(0.4)
          from(1.0)
        end

      assert %Transition{to: 0.4, from: 1.0, duration: 800, repeat: :forever} = t
    end
  end

  # ---------------------------------------------------------------------------
  # spring macro
  # ---------------------------------------------------------------------------

  describe "spring macro" do
    test "keyword form" do
      s = spring(to: 1.05, preset: :bouncy)
      assert %Spring{to: 1.05, stiffness: 300, damping: 10} = s
    end

    test "keyword form with custom params" do
      s = spring(to: 1.05, stiffness: 200, damping: 20)
      assert %Spring{to: 1.05, stiffness: 200, damping: 20} = s
    end

    test "do-block form" do
      s =
        spring do
          to(1.05)
          stiffness(200)
          damping(20)
        end

      assert %Spring{to: 1.05, stiffness: 200, damping: 20} = s
    end

    test "used as a prop value on container" do
      node =
        container "box", max_width: spring(to: 200, preset: :bouncy) do
        end

      assert %Spring{} = node.props[:max_width]
    end
  end

  # ---------------------------------------------------------------------------
  # sequence macro
  # ---------------------------------------------------------------------------

  describe "sequence macro" do
    test "list form" do
      s =
        sequence([
          transition(200, to: 1.0, from: 0.0),
          transition(300, to: 0.0)
        ])

      assert %Sequence{} = s
      assert length(s.steps) == 2
    end

    test "do-block form" do
      s =
        sequence do
          transition(200, to: 1.0, from: 0.0)
          transition(300, to: 0.0)
        end

      assert %Sequence{} = s
      assert length(s.steps) == 2
    end

    test "do-block with single step" do
      s =
        sequence do
          transition(200, to: 1.0, from: 0.0)
        end

      assert length(s.steps) == 1
    end

    test "mixed transition and spring in sequence" do
      s =
        sequence([
          transition(200, to: 1.0, from: 0.0),
          spring(to: 0.5, preset: :bouncy)
        ])

      assert length(s.steps) == 2
      assert %Transition{} = hd(s.steps)
      assert %Spring{} = Enum.at(s.steps, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Encode integration (descriptors as prop values)
  # ---------------------------------------------------------------------------

  describe "encode integration" do
    test "transition descriptor survives tree normalization" do
      node =
        window "main", title: "Test" do
          container "box", max_width: transition(300, to: 200) do
          end
        end
        |> Plushie.Tree.normalize()

      box = Plushie.Tree.find(node, "box")
      assert is_map(box.props[:max_width])
      assert box.props[:max_width]["type"] == "transition"
      assert box.props[:max_width]["to"] == 200
      assert box.props[:max_width]["duration"] == 300
    end

    test "spring descriptor survives tree normalization" do
      node =
        window "main", title: "Test" do
          container "box", max_width: spring(to: 200, preset: :bouncy) do
          end
        end
        |> Plushie.Tree.normalize()

      box = Plushie.Tree.find(node, "box")
      assert box.props[:max_width]["type"] == "spring"
      assert box.props[:max_width]["to"] == 200
    end

    test "sequence descriptor survives tree normalization" do
      node =
        window "main", title: "Test" do
          container "box",
            max_width:
              sequence([
                transition(200, to: 200, from: 0),
                transition(300, to: 0)
              ]) do
          end
        end
        |> Plushie.Tree.normalize()

      box = Plushie.Tree.find(node, "box")
      assert box.props[:max_width]["type"] == "sequence"
      assert length(box.props[:max_width]["steps"]) == 2
    end

    test "exit prop encodes as a map with transition descriptors" do
      node =
        window "main", title: "Test" do
          container "item",
            exit: [max_width: transition(200, to: 0)],
            max_width: transition(200, to: 300, from: 0) do
          end
        end
        |> Plushie.Tree.normalize()

      item = Plushie.Tree.find(node, "item")
      assert is_map(item.props[:exit])
      assert item.props[:exit][:max_width]["type"] == "transition"
      assert item.props[:exit][:max_width]["to"] == 0
    end
  end
end
