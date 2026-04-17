defmodule Plushie.Test.A11yHelpersTest do
  use ExUnit.Case, async: true

  alias Plushie.Automation.Element

  describe "Element.a11y/1" do
    test "returns a11y map when present" do
      el = %Element{
        id: "btn",
        type: "button",
        props: %{label: "Go", a11y: %{label: "Go forward"}},
        children: []
      }

      assert Element.a11y(el) == %{label: "Go forward"}
    end

    test "returns nil when a11y not set" do
      el = %Element{id: "btn", type: "button", props: %{label: "Go"}, children: []}
      assert Element.a11y(el) == nil
    end
  end

  describe "Element.inferred_role/1" do
    test "button infers button role" do
      el = %Element{id: "b", type: "button", props: %{a11y: %{role: :button}}, children: []}
      assert Element.inferred_role(el) == "button"
    end

    test "text infers label role" do
      el = %Element{id: "t", type: "text", props: %{a11y: %{role: :label}}, children: []}
      assert Element.inferred_role(el) == "label"
    end

    test "checkbox infers check_box role" do
      el = %Element{id: "cb", type: "checkbox", props: %{a11y: %{role: :check_box}}, children: []}
      assert Element.inferred_role(el) == "check_box"
    end

    test "slider infers slider role" do
      el = %Element{id: "sl", type: "slider", props: %{a11y: %{role: :slider}}, children: []}
      assert Element.inferred_role(el) == "slider"
    end

    test "container infers generic_container role" do
      el = %Element{
        id: "c",
        type: "container",
        props: %{a11y: %{role: :generic_container}},
        children: []
      }

      assert Element.inferred_role(el) == "generic_container"
    end

    test "a11y role override takes precedence" do
      el = %Element{
        id: "h",
        type: "text",
        props: %{a11y: %{role: "heading"}},
        children: []
      }

      assert Element.inferred_role(el) == "heading"
    end

    test "unknown type returns unknown" do
      el = %Element{id: "x", type: "custom_widget", props: %{}, children: []}
      assert Element.inferred_role(el) == "unknown"
    end

    test "rule infers splitter role" do
      el = %Element{id: "r", type: "rule", props: %{a11y: %{role: :splitter}}, children: []}
      assert Element.inferred_role(el) == "splitter"
    end

    test "toggler infers switch role" do
      el = %Element{id: "tg", type: "toggler", props: %{a11y: %{role: :switch}}, children: []}
      assert Element.inferred_role(el) == "switch"
    end
  end

  describe "Element.resolved_a11y/1" do
    test "text_input placeholder flows into description when unset" do
      el = %Element{
        id: "search",
        type: "text_input",
        props: %{placeholder: "Search..."},
        children: []
      }

      assert Element.resolved_a11y(el) == %{description: "Search..."}
    end

    test "image alt flows into label when unset" do
      el = %Element{
        id: "photo",
        type: "image",
        props: %{alt: "A tree"},
        children: []
      }

      assert Element.resolved_a11y(el) == %{label: "A tree"}
    end

    test "explicit a11y composes with inferred values" do
      el = %Element{
        id: "search",
        type: "text_input",
        props: %{
          placeholder: "Search...",
          a11y: %{label: "Search box", required: true}
        },
        children: []
      }

      resolved = Element.resolved_a11y(el)
      assert resolved[:description] == "Search..."
      assert resolved[:label] == "Search box"
      assert resolved[:required] == true
    end

    test "explicit description overrides inferred" do
      el = %Element{
        id: "search",
        type: "text_input",
        props: %{
          placeholder: "Search...",
          a11y: %{description: "Enter a query"}
        },
        children: []
      }

      assert Element.resolved_a11y(el)[:description] == "Enter a query"
    end

    test "returns empty map for widgets the normalizer left untouched" do
      el = %Element{id: "x", type: "text", props: %{content: "hi"}, children: []}
      assert Element.resolved_a11y(el) == %{}
    end

    test "blank placeholder is treated as absent" do
      el = %Element{id: "x", type: "text_input", props: %{placeholder: ""}, children: []}
      assert Element.resolved_a11y(el) == %{}
    end
  end
end
