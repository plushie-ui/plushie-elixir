defmodule Julep.Iced.A11yTest do
  use ExUnit.Case, async: true

  alias Julep.Iced.Widget.{Button, Column, Container, Slider, Text}
  alias Julep.Tree

  describe "a11y prop on widget structs" do
    test "Button carries a11y prop through to_node" do
      btn = Button.new("b1", "Go", a11y: %{label: "Go forward"})
      node = Tree.normalize(Julep.Iced.Widget.to_node(btn))
      assert node.props["a11y"]["label"] == "Go forward"
    end

    test "Column carries a11y prop through to_node" do
      col = Column.new("col", a11y: %{role: "navigation"})
      node = Tree.normalize(Julep.Iced.Widget.to_node(col))
      assert node.props["a11y"]["role"] == "navigation"
    end

    test "Slider carries a11y prop through to_node" do
      sl = Slider.new("sl", {0, 100}, 50, a11y: %{label: "Volume"})
      node = Tree.normalize(Julep.Iced.Widget.to_node(sl))
      assert node.props["a11y"]["label"] == "Volume"
    end

    test "Container with hidden a11y prop" do
      c = Container.new("c1", a11y: %{hidden: true})
      node = Tree.normalize(Julep.Iced.Widget.to_node(c))
      assert node.props["a11y"]["hidden"] == true
    end

    test "Text with heading role and level" do
      t = Text.new("h1", "Title") |> Text.a11y(%{role: "heading", level: 1})
      node = Tree.normalize(Julep.Iced.Widget.to_node(t))
      assert node.props["a11y"]["role"] == "heading"
      assert node.props["a11y"]["level"] == 1
    end

    test "a11y prop is nil by default" do
      btn = Button.new("b1", "Go")
      node = Tree.normalize(Julep.Iced.Widget.to_node(btn))
      refute Map.has_key?(node.props, "a11y")
    end

    test "a11y builder function works" do
      btn = Button.new("b1", "X") |> Button.a11y(%{label: "Close"})
      node = Tree.normalize(Julep.Iced.Widget.to_node(btn))
      assert node.props["a11y"]["label"] == "Close"
    end
  end
end
