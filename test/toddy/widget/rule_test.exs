defmodule Toddy.Widget.RuleTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Rule

  describe "new/1" do
    test "creates rule with id" do
      rule = Rule.new("r1")
      assert %Rule{} = rule
      assert rule.id == "r1"
    end

    test "all optional fields default to nil" do
      rule = Rule.new("r1")
      assert rule.height == nil
      assert rule.width == nil
      assert rule.direction == nil
      assert rule.style == nil
    end

    test "accepts keyword opts" do
      rule = Rule.new("r1", height: 2, direction: :vertical)
      assert rule.height == 2
      assert rule.direction == :vertical
    end
  end

  describe "height/2" do
    test "sets the height field" do
      rule = Rule.new("r") |> Rule.height(3)
      assert rule.height == 3
    end
  end

  describe "width/2" do
    test "sets the width field" do
      rule = Rule.new("r") |> Rule.width(5)
      assert rule.width == 5
    end
  end

  describe "direction/2" do
    test "sets the direction field" do
      rule = Rule.new("r") |> Rule.direction(:vertical)
      assert rule.direction == :vertical
    end
  end

  describe "style/2" do
    test "sets the style field" do
      rule = Rule.new("r") |> Rule.style(:weak)
      assert rule.style == :weak
    end
  end

  describe "build/1" do
    test "returns a map with correct type and id" do
      node = Rule.new("r1") |> Rule.build()
      assert node.type == "rule"
      assert node.id == "r1"
      assert node.children == []
    end

    test "includes non-nil props" do
      node =
        Rule.new("r1")
        |> Rule.height(2)
        |> Rule.direction(:horizontal)
        |> Rule.style(:default)
        |> Rule.build()

      assert node.props[:height] == 2
      assert node.props[:direction] == :horizontal
      assert node.props[:style] == :default
    end

    test "omits nil props" do
      node = Rule.new("r1") |> Rule.build()
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "direction")
      refute Map.has_key?(node.props, "style")
    end
  end

  describe "with_options/2" do
    test "routes all supported options" do
      rule = Rule.new("r", height: 4, width: 2, direction: :vertical, style: :weak)
      assert rule.height == 4
      assert rule.width == 2
      assert rule.direction == :vertical
      assert rule.style == :weak
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:colour/, fn ->
        Rule.new("r", colour: "red")
      end
    end
  end
end
