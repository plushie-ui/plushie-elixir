defmodule Toddy.Test.WidgetCatalogTest do
  use ExUnit.Case, async: true

  alias Toddy.Iced.Widget

  alias Toddy.Iced.Widget.{
    Button,
    Checkbox,
    Column,
    Container,
    PickList,
    Row,
    Slider,
    Text,
    TextInput,
    Toggler
  }

  alias Toddy.Tree

  # Helpers

  defp normalize(widget), do: Tree.normalize(widget)

  defp node(type, id, props \\ %{}, children \\ []) do
    %{id: id, type: type, props: props, children: children}
  end

  # -- Tree.normalize on plain maps --

  describe "normalize/1 with plain maps" do
    test "nil input returns empty root container" do
      result = Tree.normalize(nil)
      assert result.id == "root"
      assert result.type == "container"
      assert result.props == %{}
      assert result.children == []
    end

    test "empty list returns empty root container" do
      result = Tree.normalize([])
      assert result.type == "container"
    end

    test "single-element list unwraps to the node" do
      nodes = [node("button", "b1", %{"label" => "Go"})]
      result = Tree.normalize(nodes)
      assert result.type == "button"
      assert result.id == "b1"
    end

    test "multi-element list wraps in root container" do
      nodes = [node("text", "t1"), node("button", "b1")]
      result = Tree.normalize(nodes)
      assert result.type == "container"
      assert result.id == "root"
      assert length(result.children) == 2
    end

    test "atom keys are normalized to string keys" do
      raw = %{id: "btn", type: "button", props: %{label: "Go"}, children: []}
      result = Tree.normalize(raw)
      assert result.props["label"] == "Go"
      refute Map.has_key?(result.props, :label)
    end

    test "children are normalized recursively" do
      raw = %{
        id: "col",
        type: "column",
        props: %{},
        children: [
          %{id: "child", type: "text", props: %{content: "hi"}, children: []}
        ]
      }

      result = Tree.normalize(raw)
      [child] = result.children
      assert child.props["content"] == "hi"
    end

    test "missing props defaults to empty map" do
      result = Tree.normalize(%{id: "x", type: "text"})
      assert result.props == %{}
    end

    test "missing children defaults to empty list" do
      result = Tree.normalize(%{id: "x", type: "text", props: %{}})
      assert result.children == []
    end

    test "missing id generates unique unknown_ prefix" do
      result = Tree.normalize(%{type: "text", props: %{}, children: []})
      assert String.starts_with?(result.id, "unknown_")
    end
  end

  # -- Button --

  describe "Button widget" do
    test "type is button" do
      result = normalize(Button.new("b1", "Click me"))
      assert result.type == "button"
    end

    test "id is preserved" do
      result = normalize(Button.new("save", "Save"))
      assert result.id == "save"
    end

    test "label prop present" do
      result = normalize(Button.new("b1", "OK"))
      assert result.props["label"] == "OK"
    end

    test "style prop included when set" do
      result = normalize(Button.new("b1", "Go", style: :danger))
      assert result.props["style"] == "danger"
    end

    test "disabled prop included when set" do
      result = normalize(Button.new("b1", "Go", disabled: true))
      assert result.props["disabled"] == true
    end

    test "no children" do
      result = normalize(Button.new("b1", "Go"))
      assert result.children == []
    end
  end

  # -- TextInput --

  describe "TextInput widget" do
    test "type is text_input" do
      result = normalize(TextInput.new("ti", "hello"))
      assert result.type == "text_input"
    end

    test "value prop reflects constructor arg" do
      result = normalize(TextInput.new("ti", "world"))
      assert result.props["value"] == "world"
    end

    test "placeholder prop included when set" do
      result = normalize(TextInput.new("ti", "", placeholder: "Enter text"))
      assert result.props["placeholder"] == "Enter text"
    end

    test "on_submit prop included when set" do
      result = normalize(TextInput.new("ti", "", on_submit: true))
      assert result.props["on_submit"] == true
    end

    test "no children" do
      result = normalize(TextInput.new("ti", ""))
      assert result.children == []
    end
  end

  # -- Checkbox --

  describe "Checkbox widget" do
    test "type is checkbox" do
      result = normalize(Checkbox.new("cb", "Accept", false))
      assert result.type == "checkbox"
    end

    test "label prop present" do
      result = normalize(Checkbox.new("cb", "Accept", false))
      assert result.props["label"] == "Accept"
    end

    test "checked prop reflects is_toggled false" do
      result = normalize(Checkbox.new("cb", "Accept", false))
      # put_if skips nil but not false; false is a valid prop value
      refute result.props["checked"]
    end

    test "checked prop reflects is_toggled true" do
      result = normalize(Checkbox.new("cb", "Accept", true))
      assert result.props["checked"] == true
    end

    test "no children" do
      result = normalize(Checkbox.new("cb", "Label", false))
      assert result.children == []
    end
  end

  # -- Toggler --

  describe "Toggler widget" do
    test "type is toggler" do
      result = normalize(Toggler.new("tg", false))
      assert result.type == "toggler"
    end

    test "is_toggled prop emitted for true state" do
      result = normalize(Toggler.new("tg", true))
      assert result.props["is_toggled"] == true
    end

    test "label prop included when set" do
      result = normalize(Toggler.new("tg", false, label: "Dark mode"))
      assert result.props["label"] == "Dark mode"
    end
  end

  # -- Slider --

  describe "Slider widget" do
    test "type is slider" do
      result = normalize(Slider.new("sl", {0, 100}, 50))
      assert result.type == "slider"
    end

    test "value prop reflects constructor arg" do
      result = normalize(Slider.new("sl", {0, 100}, 42))
      assert result.props["value"] == 42
    end

    test "range prop present as list" do
      result = normalize(Slider.new("sl", {0, 100}, 0))
      # Tuples are encoded by the Encode protocol as lists
      assert result.props["range"] == [0, 100]
    end

    test "step prop included when set" do
      result = normalize(Slider.new("sl", {0, 100}, 0, step: 5))
      assert result.props["step"] == 5
    end
  end

  # -- PickList --

  describe "PickList widget" do
    test "type is pick_list" do
      result = normalize(PickList.new("pl", ["a", "b"]))
      assert result.type == "pick_list"
    end

    test "options prop reflects list" do
      result = normalize(PickList.new("pl", ["NZ", "AU", "GB"]))
      assert result.props["options"] == ["NZ", "AU", "GB"]
    end

    test "selected prop present when set" do
      result = normalize(PickList.new("pl", ["NZ", "AU"], selected: "NZ"))
      assert result.props["selected"] == "NZ"
    end

    test "placeholder prop present when set" do
      result = normalize(PickList.new("pl", [], placeholder: "Choose..."))
      assert result.props["placeholder"] == "Choose..."
    end
  end

  # -- Text --

  describe "Text widget" do
    test "type is text" do
      result = normalize(Text.new("t1", "Hello"))
      assert result.type == "text"
    end

    test "content prop reflects constructor arg" do
      result = normalize(Text.new("t1", "Goodbye"))
      assert result.props["content"] == "Goodbye"
    end
  end

  # -- Column --

  describe "Column widget" do
    test "type is column" do
      result = normalize(Column.new("col"))
      assert result.type == "column"
    end

    test "empty column has no children" do
      result = normalize(Column.new("col"))
      assert result.children == []
    end

    test "pushed children appear in normalized tree" do
      col =
        Column.new("col")
        |> Column.push(Button.new("b1", "Go"))
        |> Column.push(Text.new("t1", "Hi"))

      result = normalize(col)
      assert length(result.children) == 2
      [btn, txt] = result.children
      assert btn.type == "button"
      assert txt.type == "text"
    end

    test "spacing prop included when set" do
      result = normalize(Column.new("col", spacing: 8))
      assert result.props["spacing"] == 8
    end
  end

  # -- Row --

  describe "Row widget" do
    test "type is row" do
      result = normalize(Row.new("row"))
      assert result.type == "row"
    end

    test "pushed children appear in normalized tree" do
      row =
        Row.new("row")
        |> Row.push(Button.new("b1", "Yes"))
        |> Row.push(Button.new("b2", "No"))

      result = normalize(row)
      assert length(result.children) == 2
    end
  end

  # -- Container --

  describe "Container widget" do
    test "type is container" do
      result = normalize(Container.new("c1"))
      assert result.type == "container"
    end

    test "child is preserved" do
      c = Container.new("c1") |> Container.push(Text.new("t1", "inner"))
      result = normalize(c)
      assert length(result.children) == 1
      [child] = result.children
      assert child.type == "text"
    end

    test "padding prop included when set" do
      result = normalize(Container.new("c1", padding: 16))
      assert result.props["padding"] == 16
    end
  end

  # -- Tree.find on normalized trees --

  describe "Tree.find/2 on normalized trees" do
    setup do
      col =
        Column.new("col")
        |> Column.push(Button.new("save", "Save"))
        |> Column.push(
          Container.new("wrapper")
          |> Container.push(Text.new("msg", "Done"))
        )

      {:ok, tree: Tree.normalize(col)}
    end

    test "finds root node by id", %{tree: tree} do
      result = Tree.find(tree, "col")
      assert result.type == "column"
    end

    test "finds direct child by scoped id", %{tree: tree} do
      result = Tree.find(tree, "col/save")
      assert result.type == "button"
    end

    test "finds direct child by local id", %{tree: tree} do
      result = Tree.find(tree, "save")
      assert result.type == "button"
      assert result.id == "col/save"
    end

    test "finds deeply nested node by scoped id", %{tree: tree} do
      result = Tree.find(tree, "col/wrapper/msg")
      assert result.type == "text"
      assert result.props["content"] == "Done"
    end

    test "finds deeply nested node by local id", %{tree: tree} do
      result = Tree.find(tree, "msg")
      assert result.type == "text"
      assert result.id == "col/wrapper/msg"
    end

    test "returns nil for missing id", %{tree: tree} do
      assert Tree.find(tree, "ghost") == nil
    end

    test "Tree.exists?/2 returns true for present node", %{tree: tree} do
      assert Tree.exists?(tree, "col/save")
    end

    test "Tree.exists?/2 returns false for absent node", %{tree: tree} do
      refute Tree.exists?(tree, "phantom")
    end

    test "Tree.ids/1 lists all node ids depth-first", %{tree: tree} do
      ids = Tree.ids(tree)
      assert "col" in ids
      assert "col/save" in ids
      assert "col/wrapper" in ids
      assert "col/wrapper/msg" in ids
    end
  end

  # -- Widget protocol dispatch --

  describe "Toddy.Iced.Widget protocol" do
    test "to_node dispatches through protocol for each struct type" do
      for widget <- [
            Button.new("b", "Go"),
            TextInput.new("ti", ""),
            Checkbox.new("cb", "Check", false),
            Toggler.new("tg", false),
            Slider.new("sl", {0, 100}, 0),
            PickList.new("pl", ["a"]),
            Text.new("t", "hi"),
            Column.new("c"),
            Row.new("r"),
            Container.new("cx")
          ] do
        node = Widget.to_node(widget)
        assert is_map(node), "expected map from #{inspect(widget.__struct__)}"
        assert is_binary(node.id), "expected string id from #{inspect(widget.__struct__)}"
        assert is_binary(node.type), "expected string type from #{inspect(widget.__struct__)}"
        assert is_map(node.props), "expected map props from #{inspect(widget.__struct__)}"
        assert is_list(node.children), "expected list children from #{inspect(widget.__struct__)}"
      end
    end
  end
end
