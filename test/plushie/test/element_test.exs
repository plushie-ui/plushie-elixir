defmodule Plushie.Test.ElementTest do
  use ExUnit.Case, async: true

  alias Plushie.Test.Element

  describe "from_node/1" do
    test "creates element from atom-keyed map" do
      node = %{id: "btn", type: "button", props: %{label: "OK"}, children: []}
      element = Element.from_node(node)

      assert element.id == "btn"
      assert element.type == "button"
      assert element.props == %{label: "OK"}
      assert element.children == []
    end

    test "creates element from string-keyed map" do
      node = %{"id" => "txt", "type" => "text", "props" => %{"content" => "hi"}, "children" => []}
      element = Element.from_node(node)

      assert element.id == "txt"
      assert element.type == "text"
      assert element.props == %{content: "hi"}
      assert element.children == []
    end

    test "defaults props to empty map when missing" do
      node = %{id: "bare", type: "container"}
      element = Element.from_node(node)

      assert element.props == %{}
      assert element.children == []
    end

    test "recursively converts nested children" do
      node = %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{id: "child-1", type: "text", props: %{content: "first"}, children: []},
          %{
            id: "child-2",
            type: "row",
            props: %{},
            children: [
              %{id: "grandchild", type: "button", props: %{label: "deep"}, children: []}
            ]
          }
        ]
      }

      element = Element.from_node(node)

      assert length(element.children) == 2
      assert %Element{id: "child-1", type: "text"} = Enum.at(element.children, 0)

      row = Enum.at(element.children, 1)
      assert row.id == "child-2"
      assert length(row.children) == 1
      assert %Element{id: "grandchild", type: "button"} = hd(row.children)
    end
  end

  describe "text/1" do
    test "extracts content prop" do
      element =
        Element.from_node(%{id: "t", type: "text", props: %{content: "hello"}, children: []})

      assert Element.text(element) == "hello"
    end

    test "extracts label prop" do
      element =
        Element.from_node(%{
          id: "b",
          type: "button",
          props: %{label: "click me"},
          children: []
        })

      assert Element.text(element) == "click me"
    end

    test "extracts value prop" do
      element =
        Element.from_node(%{
          id: "i",
          type: "text_input",
          props: %{value: "typed"},
          children: []
        })

      assert Element.text(element) == "typed"
    end

    test "extracts placeholder prop" do
      element =
        Element.from_node(%{
          id: "i",
          type: "text_input",
          props: %{placeholder: "enter..."},
          children: []
        })

      assert Element.text(element) == "enter..."
    end

    test "returns nil when no text prop present" do
      element =
        Element.from_node(%{id: "c", type: "container", props: %{spacing: 8}, children: []})

      assert Element.text(element) == nil
    end

    test "prefers content over label over value over placeholder" do
      element =
        Element.from_node(%{
          id: "x",
          type: "widget",
          props: %{content: "a", label: "b", value: "c", placeholder: "d"},
          children: []
        })

      assert Element.text(element) == "a"
    end
  end
end
