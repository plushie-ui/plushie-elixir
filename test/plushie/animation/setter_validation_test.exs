defmodule Plushie.Animation.SetterValidationTest do
  use ExUnit.Case, async: true

  alias Plushie.Animation.{Sequence, Spring, Transition}
  alias Plushie.Widget.{Container, Text}

  describe "animation through widget setters" do
    test "transition on float field stores the descriptor" do
      widget = Text.new("t", "hello", size: Transition.new(300, to: 24.0))
      assert %Transition{to: 24.0, duration: 300} = widget.size
    end

    test "spring on float field stores the descriptor" do
      widget = Text.new("t", "hello", size: Spring.new(to: 18.0, preset: :bouncy))
      assert %Spring{to: 18.0} = widget.size
    end

    test "sequence on float field stores the descriptor" do
      seq =
        Sequence.new([
          Transition.new(200, to: 10.0, from: 20.0),
          Transition.new(300, to: 30.0)
        ])

      widget = Text.new("t", "hello", size: seq)
      assert %Sequence{} = widget.size
    end

    test "transition on color field stores the descriptor" do
      widget = Text.new("t", "hello", color: Transition.new(300, to: :red))
      assert %Transition{to: :red} = widget.color
    end

    test "spring on color field stores the descriptor" do
      widget = Text.new("t", "hello", color: Spring.new(to: "#ff0000"))
      assert %Spring{to: "#ff0000"} = widget.color
    end

    test "transition on container max_width" do
      widget = Container.new("c", max_width: Transition.new(300, to: 200.0))
      assert %Transition{to: 200.0} = widget.max_width
    end

    test "transition on container max_height" do
      widget = Container.new("c", max_height: Spring.new(to: 100.0, preset: :snappy))
      assert %Spring{to: 100.0} = widget.max_height
    end

    test "pipeline setter accepts transition" do
      widget = Text.new("t", "hello") |> Text.size(Transition.new(300, to: 14.0))
      assert %Transition{to: 14.0} = widget.size
    end

    test "pipeline setter accepts spring" do
      widget = Container.new("c") |> Container.max_width(Spring.new(to: 200.0))
      assert %Spring{to: 200.0} = widget.max_width
    end
  end

  describe "animation target validation" do
    test "raises for invalid float target" do
      assert_raise ArgumentError, ~r/animation target for :size must be a valid/, fn ->
        Text.new("t", "hello", size: Transition.new(300, to: "not_a_float"))
      end
    end

    test "raises for invalid float spring target" do
      assert_raise ArgumentError, ~r/animation target for :max_width must be a valid/, fn ->
        Container.new("c", max_width: Spring.new(to: "bad"))
      end
    end

    test "raises for invalid color target" do
      assert_raise ArgumentError, ~r/animation target for :color must be a valid/, fn ->
        Text.new("t", "hello", color: Transition.new(300, to: 99_999))
      end
    end

    test "raises for invalid from value" do
      assert_raise ArgumentError, ~r/animation :from for :size must be a valid/, fn ->
        Text.new("t", "hello", size: Transition.new(300, to: 24.0, from: "bad"))
      end
    end

    test "sequence validates first step target" do
      seq =
        Sequence.new([
          Transition.new(200, to: "not_a_float"),
          Transition.new(300, to: 30.0)
        ])

      assert_raise ArgumentError, ~r/animation target for :size must be a valid/, fn ->
        Text.new("t", "hello", size: seq)
      end
    end

    test "valid from value passes" do
      widget = Text.new("t", "hello", size: Transition.new(300, to: 24.0, from: 12.0))
      assert %Transition{to: 24.0, from: 12.0} = widget.size
    end

    test "nil from value is accepted" do
      widget = Text.new("t", "hello", size: Transition.new(300, to: 24.0))
      assert widget.size.from == nil
    end
  end

  describe "exit animations still work" do
    test "exit prop passes through build_node" do
      import Plushie.UI

      node =
        container "item",
          exit: [max_width: transition(200, to: 0)],
          max_width: transition(200, to: 300, from: 0) do
        end

      assert is_map(node.props[:exit])
      assert %Transition{to: 0} = node.props[:exit][:max_width]
    end
  end

  describe "to_node encodes animation descriptors" do
    test "transition in float field survives to_node" do
      node =
        Container.new("c", max_width: Transition.new(300, to: 200.0))
        |> Container.build()

      assert %Transition{to: 200.0} = node.props[:max_width]
    end

    test "transition in color field survives to_node" do
      node =
        Text.new("t", "hello", color: Transition.new(300, to: :red))
        |> Text.build()

      assert %Transition{to: :red} = node.props[:color]
    end

    test "animation descriptor encodes through tree normalize" do
      node =
        Container.new("c", max_width: Transition.new(300, to: 200.0))
        |> Container.build()

      normalized = Plushie.Tree.normalize(node)
      assert normalized.props[:max_width]["type"] == "transition"
      assert normalized.props[:max_width]["to"] == 200.0
    end
  end
end
