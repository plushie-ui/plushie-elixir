defmodule Plushie.Automation.SelectorTest do
  use ExUnit.Case, async: true

  alias Plushie.Automation.Selector

  describe "parse/1" do
    test "window-qualified ID selector" do
      assert {"main", "#save"} = Selector.parse("main#save")
    end

    test "window-qualified scoped ID selector" do
      assert {"main", "#form/save"} = Selector.parse("main#form/save")
    end

    test "plain ID selector without window" do
      assert {nil, "#save"} = Selector.parse("#save")
    end

    test "scoped ID selector without window" do
      assert {nil, "#form/save"} = Selector.parse("#form/save")
    end

    test "non-string selectors pass through unchanged" do
      assert {nil, {:text, "Save"}} = Selector.parse({:text, "Save"})
      assert {nil, {:role, "button"}} = Selector.parse({:role, "button"})
      assert {nil, :focused} = Selector.parse(:focused)
    end

    test "bare string without # is returned as-is (no window)" do
      assert {nil, "save"} = Selector.parse("save")
    end
  end

  describe "find/2 with window-qualified selectors" do
    setup do
      tree = %{
        type: "root",
        id: "root",
        props: %{},
        children: [
          %{
            type: "window",
            id: "main",
            props: %{},
            children: [
              %{type: "button", id: "save", props: %{}, children: []},
              %{
                type: "container",
                id: "form",
                props: %{},
                children: [
                  %{type: "text_input", id: "form/email", props: %{}, children: []}
                ]
              }
            ]
          },
          %{
            type: "window",
            id: "settings",
            props: %{},
            children: [
              %{type: "button", id: "save", props: %{}, children: []},
              %{type: "button", id: "apply", props: %{}, children: []}
            ]
          }
        ]
      }

      {:ok, tree: tree}
    end

    test "finds widget in specific window", %{tree: tree} do
      element = Selector.find(tree, "settings#apply")
      assert element != nil
      assert element.id == "apply"
    end

    test "returns nil when widget not in specified window", %{tree: tree} do
      assert Selector.find(tree, "settings#form/email") == nil
    end

    test "finds scoped widget in specific window", %{tree: tree} do
      element = Selector.find(tree, "main#form/email")
      assert element != nil
      assert element.id == "form/email"
    end
  end

  describe "find_node/2 with window-qualified selectors" do
    setup do
      tree = %{
        type: "root",
        id: "root",
        props: %{},
        children: [
          %{
            type: "window",
            id: "main",
            props: %{},
            children: [
              %{type: "button", id: "save", props: %{content: "Save"}, children: []}
            ]
          }
        ]
      }

      {:ok, tree: tree}
    end

    test "finds raw node with window qualifier", %{tree: tree} do
      node = Selector.find_node(tree, "main#save")
      assert node != nil
      assert node[:id] == "save"
      assert node[:props][:content] == "Save"
    end

    test "returns nil when window does not match", %{tree: tree} do
      assert Selector.find_node(tree, "other#save") == nil
    end

    test "plain ID selector still works", %{tree: tree} do
      node = Selector.find_node(tree, "#save")
      assert node != nil
      assert node[:id] == "save"
    end
  end

  describe "encode/3 with window-qualified selectors" do
    test "extracts window_id from selector" do
      sel = Selector.encode("main#save", nil)
      assert sel["by"] == "id"
      assert sel["value"] == "save"
      assert sel["window_id"] == "main"
    end

    test "extracts window_id from scoped selector" do
      sel = Selector.encode("main#form/save", nil)
      assert sel["by"] == "id"
      assert sel["value"] == "form/save"
      assert sel["window_id"] == "main"
    end

    test "plain ID selector has no window_id" do
      sel = Selector.encode("#save", nil)
      assert sel["by"] == "id"
      assert sel["value"] == "save"
      refute Map.has_key?(sel, "window_id")
    end

    test "explicit window_id parameter takes precedence" do
      sel = Selector.encode("main#save", nil, "override")
      assert sel["window_id"] == "override"
    end

    test "explicit window_id used when selector has none" do
      sel = Selector.encode("#save", nil, "main")
      assert sel["window_id"] == "main"
    end
  end

  describe "parse_selector/1 pseudo-selectors" do
    test "preserves focused pseudo-selector" do
      assert {nil, :focused} = Selector.parse_selector(":focused")
      assert {"main", :focused} = Selector.parse_selector("main#:focused")
    end

    test "unknown pseudo-selector does not raise" do
      assert {nil, {:unknown_pseudo, "not_a_real_selector"}} =
               Selector.parse_selector(":not_a_real_selector")
    end

    test "unknown pseudo-selector does not match or crash during encode" do
      tree = %{
        type: "root",
        id: "root",
        props: %{},
        children: [%{type: "button", id: "save", props: %{}, children: []}]
      }

      assert Selector.find(tree, ":not_a_real_selector") == nil

      assert %{"by" => "unknown_pseudo", "value" => "not_a_real_selector"} =
               Selector.encode(":not_a_real_selector", tree)
    end
  end
end
