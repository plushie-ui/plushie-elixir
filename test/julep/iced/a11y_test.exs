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

  alias Julep.Iced.A11y

  describe "struct creation with new fields" do
    test "busy field" do
      a = %A11y{busy: true}
      assert a.busy == true
    end

    test "invalid field" do
      a = %A11y{invalid: true}
      assert a.invalid == true
    end

    test "modal field" do
      a = %A11y{modal: true}
      assert a.modal == true
    end

    test "read_only field" do
      a = %A11y{read_only: true}
      assert a.read_only == true
    end

    test "mnemonic field" do
      a = %A11y{mnemonic: "S"}
      assert a.mnemonic == "S"
    end

    test "new fields default to nil" do
      a = %A11y{}
      assert a.busy == nil
      assert a.invalid == nil
      assert a.modal == nil
      assert a.read_only == nil
      assert a.mnemonic == nil
    end
  end

  describe "cast/1 with new fields" do
    test "cast bare map with busy" do
      a = A11y.cast(%{busy: true, label: "Loading"})
      assert %A11y{busy: true, label: "Loading"} = a
    end

    test "cast bare map with invalid" do
      a = A11y.cast(%{invalid: true, required: true})
      assert %A11y{invalid: true, required: true} = a
    end

    test "cast bare map with modal" do
      a = A11y.cast(%{modal: true, role: :dialog})
      assert %A11y{modal: true, role: :dialog} = a
    end

    test "cast bare map with read_only" do
      a = A11y.cast(%{read_only: true})
      assert %A11y{read_only: true} = a
    end

    test "cast bare map with mnemonic" do
      a = A11y.cast(%{mnemonic: "F"})
      assert %A11y{mnemonic: "F"} = a
    end

    test "cast bare map with all new fields" do
      a = A11y.cast(%{busy: true, invalid: false, modal: true, read_only: true, mnemonic: "X"})
      assert a.busy == true
      assert a.invalid == false
      assert a.modal == true
      assert a.read_only == true
      assert a.mnemonic == "X"
    end

    test "cast passthrough for struct with new fields" do
      a = %A11y{busy: true, modal: true}
      assert A11y.cast(a) == a
    end
  end

  describe "mnemonic validation" do
    test "nil mnemonic passes validation" do
      a = A11y.cast(%{mnemonic: nil})
      assert a.mnemonic == nil
    end

    test "single ASCII character passes validation" do
      a = A11y.cast(%{mnemonic: "F"})
      assert a.mnemonic == "F"
    end

    test "single precomposed Unicode character passes validation" do
      a = A11y.cast(%{mnemonic: "\u00E9"})
      assert a.mnemonic == "\u00E9"
    end

    test "multi-character string raises ArgumentError" do
      assert_raise ArgumentError, ~r/single character/, fn ->
        A11y.cast(%{mnemonic: "AB"})
      end
    end
  end

  describe "encoding new fields" do
    test "nil new fields are omitted from encoding" do
      a = %A11y{label: "test"}
      encoded = Julep.Iced.Encode.encode(a)
      refute Map.has_key?(encoded, "busy")
      refute Map.has_key?(encoded, "invalid")
      refute Map.has_key?(encoded, "modal")
      refute Map.has_key?(encoded, "read_only")
      refute Map.has_key?(encoded, "mnemonic")
    end

    test "present new fields are included in encoding" do
      a = %A11y{busy: true, invalid: true, modal: true, read_only: true, mnemonic: "S"}
      encoded = Julep.Iced.Encode.encode(a)
      assert encoded["busy"] == true
      assert encoded["invalid"] == true
      assert encoded["modal"] == true
      assert encoded["read_only"] == true
      assert encoded["mnemonic"] == "S"
    end

    test "false values are preserved in encoding" do
      a = %A11y{busy: false, invalid: false}
      encoded = Julep.Iced.Encode.encode(a)
      assert encoded["busy"] == false
      assert encoded["invalid"] == false
    end
  end
end
