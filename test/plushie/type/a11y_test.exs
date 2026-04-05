defmodule Plushie.Type.A11yTest do
  use ExUnit.Case, async: true

  alias Plushie.Tree
  alias Plushie.Widget.{Button, Column, Container, Slider, Text}

  describe "a11y prop on widget structs" do
    test "Button carries a11y prop through to_node" do
      btn = Button.new("b1", "Go", a11y: %{label: "Go forward"})
      node = Tree.normalize(Plushie.Widget.to_node(btn))
      assert node.props[:a11y][:label] == "Go forward"
    end

    test "Column carries a11y prop through to_node" do
      col = Column.new("col", a11y: %{role: :navigation})
      node = Tree.normalize(Plushie.Widget.to_node(col))
      assert node.props[:a11y][:role] == "navigation"
    end

    test "Slider carries a11y prop through to_node" do
      sl = Slider.new("sl", {0, 100}, 50, a11y: %{label: "Volume"})
      node = Tree.normalize(Plushie.Widget.to_node(sl))
      assert node.props[:a11y][:label] == "Volume"
    end

    test "Container with hidden a11y prop" do
      c = Container.new("c1", a11y: %{hidden: true})
      node = Tree.normalize(Plushie.Widget.to_node(c))
      assert node.props[:a11y][:hidden] == true
    end

    test "Text with heading role and level" do
      t = Text.new("h1", "Title") |> Text.a11y(%{role: :heading, level: 1})
      node = Tree.normalize(Plushie.Widget.to_node(t))
      assert node.props[:a11y][:role] == "heading"
      assert node.props[:a11y][:level] == 1
    end

    test "a11y prop is nil by default" do
      btn = Button.new("b1", "Go")
      node = Tree.normalize(Plushie.Widget.to_node(btn))
      refute Map.has_key?(node.props, :a11y)
    end

    test "a11y builder function works" do
      btn = Button.new("b1", "X") |> Button.a11y(%{label: "Close"})
      node = Tree.normalize(Plushie.Widget.to_node(btn))
      assert node.props[:a11y][:label] == "Close"
    end
  end

  alias Plushie.Type.A11y

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

  describe "new/0 and setter functions" do
    test "new returns empty struct" do
      assert %A11y{} = A11y.new()
      assert A11y.new().role == nil
    end

    test "setter chain builds struct" do
      a = A11y.new() |> A11y.role(:heading) |> A11y.level(1) |> A11y.label("Title")
      assert a.role == :heading
      assert a.level == 1
      assert a.label == "Title"
    end

    test "all setters work" do
      a =
        A11y.new()
        |> A11y.role(:button)
        |> A11y.label("Go")
        |> A11y.description("Navigate forward")
        |> A11y.live(:polite)
        |> A11y.hidden(false)
        |> A11y.expanded(true)
        |> A11y.required(true)
        |> A11y.level(2)
        |> A11y.busy(true)
        |> A11y.invalid(false)
        |> A11y.modal(true)
        |> A11y.read_only(true)
        |> A11y.mnemonic("G")
        |> A11y.toggled(true)
        |> A11y.selected(false)
        |> A11y.value("50%")
        |> A11y.orientation(:horizontal)
        |> A11y.labelled_by("lbl")
        |> A11y.described_by("desc")
        |> A11y.error_message("err")
        |> A11y.disabled(true)
        |> A11y.position_in_set(3)
        |> A11y.size_of_set(10)
        |> A11y.has_popup("menu")

      assert a.role == :button
      assert a.label == "Go"
      assert a.description == "Navigate forward"
      assert a.live == :polite
      assert a.hidden == false
      assert a.expanded == true
      assert a.required == true
      assert a.level == 2
      assert a.busy == true
      assert a.invalid == false
      assert a.modal == true
      assert a.read_only == true
      assert a.mnemonic == "G"
      assert a.toggled == true
      assert a.selected == false
      assert a.value == "50%"
      assert a.orientation == :horizontal
      assert a.labelled_by == "lbl"
      assert a.described_by == "desc"
      assert a.error_message == "err"
      assert a.disabled == true
      assert a.position_in_set == 3
      assert a.size_of_set == 10
      assert a.has_popup == "menu"
    end

    test "role setter accepts radio_group" do
      a = A11y.new() |> A11y.role(:radio_group)
      assert a.role == :radio_group
    end

    test "role setter normalizes aliases to canonical roles" do
      a = A11y.new() |> A11y.role(:checkbox) |> A11y.role(:radio)
      assert a.role == :radio_button
    end

    test "role setter rejects unsupported roles" do
      assert_raise ArgumentError, ~r/unknown a11y role :option/, fn ->
        A11y.new() |> A11y.role(:option)
      end
    end

    test "error_message setter accepts nil" do
      a = A11y.new() |> A11y.error_message("err") |> A11y.error_message(nil)
      assert a.error_message == nil
    end
  end

  describe "cast/1 accepts keyword lists" do
    test "keyword list is cast like a map" do
      {:ok, a} = A11y.cast(role: :heading, level: 1, label: "Title")
      assert a.role == :heading
      assert a.level == 1
      assert a.label == "Title"
    end

    test "empty keyword list returns empty struct" do
      assert {:ok, %A11y{}} = A11y.cast([])
    end
  end

  describe "cast/1 with new fields" do
    test "cast bare map with busy" do
      {:ok, a} = A11y.cast(%{busy: true, label: "Loading"})
      assert %A11y{busy: true, label: "Loading"} = a
    end

    test "cast bare map with invalid" do
      {:ok, a} = A11y.cast(%{invalid: true, required: true})
      assert %A11y{invalid: true, required: true} = a
    end

    test "cast bare map with modal" do
      {:ok, a} = A11y.cast(%{modal: true, role: :dialog})
      assert %A11y{modal: true, role: :dialog} = a
    end

    test "cast bare map with read_only" do
      {:ok, a} = A11y.cast(%{read_only: true})
      assert %A11y{read_only: true} = a
    end

    test "cast bare map with mnemonic" do
      {:ok, a} = A11y.cast(%{mnemonic: "F"})
      assert %A11y{mnemonic: "F"} = a
    end

    test "cast bare map with all new fields" do
      {:ok, a} =
        A11y.cast(%{busy: true, invalid: false, modal: true, read_only: true, mnemonic: "X"})

      assert a.busy == true
      assert a.invalid == false
      assert a.modal == true
      assert a.read_only == true
      assert a.mnemonic == "X"
    end

    test "cast passthrough for struct with new fields" do
      a = %A11y{busy: true, modal: true}
      assert A11y.cast(a) == {:ok, a}
    end

    test "cast normalizes role aliases" do
      {:ok, a} = A11y.cast(%{role: :checkbox})
      assert a.role == :check_box
    end

    test "cast rejects non-atom roles" do
      assert :error = A11y.cast(%{role: "checkbox"})
    end
  end

  describe "mnemonic field" do
    test "nil mnemonic" do
      {:ok, a} = A11y.cast(%{mnemonic: nil})
      assert a.mnemonic == nil
    end

    test "single ASCII character" do
      {:ok, a} = A11y.cast(%{mnemonic: "F"})
      assert a.mnemonic == "F"
    end

    test "precomposed Unicode character" do
      {:ok, a} = A11y.cast(%{mnemonic: "\u00E9"})
      assert a.mnemonic == "\u00E9"
    end

    test "setter accepts string" do
      a = A11y.new() |> A11y.mnemonic("S")
      assert a.mnemonic == "S"
    end
  end

  describe "struct creation with toggled/selected/value/orientation" do
    test "toggled field" do
      a = %A11y{toggled: true}
      assert a.toggled == true
    end

    test "selected field" do
      a = %A11y{selected: true}
      assert a.selected == true
    end

    test "value field" do
      a = %A11y{value: "75%"}
      assert a.value == "75%"
    end

    test "orientation field" do
      a = %A11y{orientation: :horizontal}
      assert a.orientation == :horizontal
    end

    test "new state fields default to nil" do
      a = %A11y{}
      assert a.toggled == nil
      assert a.selected == nil
      assert a.value == nil
      assert a.orientation == nil
    end
  end

  describe "cast/1 with toggled/selected/value/orientation" do
    test "cast bare map with toggled" do
      {:ok, a} = A11y.cast(%{toggled: true, role: :switch})
      assert %A11y{toggled: true, role: :switch} = a
    end

    test "cast bare map with toggled false" do
      {:ok, a} = A11y.cast(%{toggled: false})
      assert %A11y{toggled: false} = a
    end

    test "cast bare map with selected" do
      {:ok, a} = A11y.cast(%{selected: true})
      assert %A11y{selected: true} = a
    end

    test "cast bare map with value" do
      {:ok, a} = A11y.cast(%{value: "42%", role: :meter})
      assert %A11y{value: "42%", role: :meter} = a
    end

    test "cast bare map with orientation horizontal" do
      {:ok, a} = A11y.cast(%{orientation: :horizontal})
      assert %A11y{orientation: :horizontal} = a
    end

    test "cast bare map with orientation vertical" do
      {:ok, a} = A11y.cast(%{orientation: :vertical})
      assert %A11y{orientation: :vertical} = a
    end

    test "cast bare map with all new state fields" do
      {:ok, a} =
        A11y.cast(%{toggled: true, selected: false, value: "50%", orientation: :vertical})

      assert a.toggled == true
      assert a.selected == false
      assert a.value == "50%"
      assert a.orientation == :vertical
    end

    test "cast passthrough preserves new state fields" do
      a = %A11y{toggled: true, value: "80%", orientation: :horizontal}
      assert A11y.cast(a) == {:ok, a}
    end
  end

  describe "encoding toggled/selected/value/orientation" do
    test "radio_group role encodes to renderer string" do
      encoded = A11y.new() |> A11y.role(:radio_group) |> Plushie.Encode.encode()
      assert encoded[:role] == "radio_group"
    end

    test "role aliases encode to canonical renderer strings" do
      encoded = A11y.new() |> A11y.role(:progress_bar) |> Plushie.Encode.encode()
      assert encoded[:role] == "progress_indicator"
    end

    test "encoding direct structs still rejects unsupported roles" do
      assert_raise ArgumentError, ~r/unknown a11y role :option/, fn ->
        %A11y{role: :option}
        |> Plushie.Encode.encode()
      end
    end

    test "nil state fields are omitted from encoding" do
      a = %A11y{label: "test"}
      encoded = Plushie.Encode.encode(a)
      refute Map.has_key?(encoded, :toggled)
      refute Map.has_key?(encoded, :selected)
      refute Map.has_key?(encoded, :value)
      refute Map.has_key?(encoded, :orientation)
    end

    test "present state fields are included in encoding" do
      a = %A11y{toggled: true, selected: false, value: "75%", orientation: :horizontal}
      encoded = Plushie.Encode.encode(a)
      assert encoded[:toggled] == true
      assert encoded[:selected] == false
      assert encoded[:value] == "75%"
      assert encoded[:orientation] == "horizontal"
    end

    test "false toggled is preserved in encoding" do
      a = %A11y{toggled: false}
      encoded = Plushie.Encode.encode(a)
      assert encoded[:toggled] == false
    end
  end

  describe "relationship fields" do
    test "labelled_by field" do
      a = %A11y{labelled_by: "email-label"}
      assert a.labelled_by == "email-label"
    end

    test "described_by field" do
      a = %A11y{described_by: "email-help"}
      assert a.described_by == "email-help"
    end

    test "error_message field" do
      a = %A11y{error_message: "email-error"}
      assert a.error_message == "email-error"
    end

    test "relationship fields default to nil" do
      a = %A11y{}
      assert a.labelled_by == nil
      assert a.described_by == nil
      assert a.error_message == nil
    end

    test "cast bare map with labelled_by" do
      {:ok, a} = A11y.cast(%{labelled_by: "name-label"})
      assert %A11y{labelled_by: "name-label"} = a
    end

    test "cast bare map with described_by" do
      {:ok, a} = A11y.cast(%{described_by: "name-help"})
      assert %A11y{described_by: "name-help"} = a
    end

    test "cast bare map with error_message" do
      {:ok, a} = A11y.cast(%{error_message: "name-error"})
      assert %A11y{error_message: "name-error"} = a
    end

    test "cast bare map with all relationship fields" do
      {:ok, a} = A11y.cast(%{labelled_by: "lb", described_by: "db", error_message: "em"})
      assert a.labelled_by == "lb"
      assert a.described_by == "db"
      assert a.error_message == "em"
    end

    test "cast passthrough preserves relationship fields" do
      a = %A11y{labelled_by: "lb", described_by: "db", error_message: "em"}
      assert A11y.cast(a) == {:ok, a}
    end
  end

  describe "encoding new fields" do
    test "nil new fields are omitted from encoding" do
      a = %A11y{label: "test"}
      encoded = Plushie.Encode.encode(a)
      refute Map.has_key?(encoded, :busy)
      refute Map.has_key?(encoded, :invalid)
      refute Map.has_key?(encoded, :modal)
      refute Map.has_key?(encoded, :read_only)
      refute Map.has_key?(encoded, :mnemonic)
    end

    test "present new fields are included in encoding" do
      a = %A11y{busy: true, invalid: true, modal: true, read_only: true, mnemonic: "S"}
      encoded = Plushie.Encode.encode(a)
      assert encoded[:busy] == true
      assert encoded[:invalid] == true
      assert encoded[:modal] == true
      assert encoded[:read_only] == true
      assert encoded[:mnemonic] == "S"
    end

    test "false values are preserved in encoding" do
      a = %A11y{busy: false, invalid: false}
      encoded = Plushie.Encode.encode(a)
      assert encoded[:busy] == false
      assert encoded[:invalid] == false
    end

    test "nil relationship fields are omitted from encoding" do
      a = %A11y{label: "test"}
      encoded = Plushie.Encode.encode(a)
      refute Map.has_key?(encoded, :labelled_by)
      refute Map.has_key?(encoded, :described_by)
      refute Map.has_key?(encoded, :error_message)
    end

    test "present relationship fields are included in encoding" do
      a = %A11y{labelled_by: "lb", described_by: "db", error_message: "em"}
      encoded = Plushie.Encode.encode(a)
      assert encoded[:labelled_by] == "lb"
      assert encoded[:described_by] == "db"
      assert encoded[:error_message] == "em"
    end
  end
end
