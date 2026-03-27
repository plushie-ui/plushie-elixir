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
      el = %Element{id: "b", type: "button", props: %{}, children: []}
      assert Element.inferred_role(el) == "button"
    end

    test "text infers label role" do
      el = %Element{id: "t", type: "text", props: %{}, children: []}
      assert Element.inferred_role(el) == "label"
    end

    test "checkbox infers check_box role" do
      el = %Element{id: "cb", type: "checkbox", props: %{}, children: []}
      assert Element.inferred_role(el) == "check_box"
    end

    test "slider infers slider role" do
      el = %Element{id: "sl", type: "slider", props: %{}, children: []}
      assert Element.inferred_role(el) == "slider"
    end

    test "container infers generic_container role" do
      el = %Element{id: "c", type: "container", props: %{}, children: []}
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
      el = %Element{id: "r", type: "rule", props: %{}, children: []}
      assert Element.inferred_role(el) == "splitter"
    end

    test "toggler infers switch role" do
      el = %Element{id: "tg", type: "toggler", props: %{}, children: []}
      assert Element.inferred_role(el) == "switch"
    end
  end
end
