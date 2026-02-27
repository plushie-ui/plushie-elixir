defmodule Julep.Test.EventMapTest do
  use ExUnit.Case, async: true

  alias Julep.Test.Element
  alias Julep.Test.EventMap

  # -- Helpers --

  defp el(id, type, props \\ %{}) do
    %Element{id: id, type: type, props: props, children: []}
  end

  # -- click/1 --

  describe "click/1" do
    test "returns click event for button" do
      assert {:ok, {:click, "save"}} = EventMap.click(el("save", "button"))
    end

    test "returns error for non-clickable types" do
      for type <- ~w[text text_input slider checkbox column container] do
        assert {:error, msg} = EventMap.click(el("x", type))
        assert msg =~ "cannot click"
        assert msg =~ type
      end
    end
  end

  # -- input/2 --

  describe "input/2" do
    test "returns input event for text_input" do
      assert {:ok, {:input, "name", "Arthur"}} =
               EventMap.input(el("name", "text_input"), "Arthur")
    end

    test "returns input event for text_editor" do
      assert {:ok, {:input, "editor", "some text"}} =
               EventMap.input(el("editor", "text_editor"), "some text")
    end

    test "returns error for non-typeable widget" do
      assert {:error, msg} = EventMap.input(el("btn", "button"), "text")
      assert msg =~ "cannot type"
    end
  end

  # -- submit/1 --

  describe "submit/1" do
    test "returns submit event for text_input with value" do
      element = el("search", "text_input", %{"value" => "query"})
      assert {:ok, {:submit, "search", "query"}} = EventMap.submit(element)
    end

    test "returns submit event with empty string when no value" do
      element = el("search", "text_input")
      assert {:ok, {:submit, "search", ""}} = EventMap.submit(element)
    end

    test "returns error for non-submittable widget" do
      assert {:error, msg} = EventMap.submit(el("x", "button"))
      assert msg =~ "cannot submit"
    end
  end

  # -- toggle/1 --

  describe "toggle/1" do
    test "flips checkbox from unchecked to checked" do
      element = el("agree", "checkbox", %{"is_checked" => false})
      assert {:ok, {:toggle, "agree", true}} = EventMap.toggle(element)
    end

    test "flips checkbox from checked to unchecked" do
      element = el("agree", "checkbox", %{"is_checked" => true})
      assert {:ok, {:toggle, "agree", false}} = EventMap.toggle(element)
    end

    test "defaults unchecked when prop missing" do
      element = el("agree", "checkbox")
      assert {:ok, {:toggle, "agree", true}} = EventMap.toggle(element)
    end

    test "flips toggler from off to on" do
      element = el("dark_mode", "toggler", %{"is_toggled" => false})
      assert {:ok, {:toggle, "dark_mode", true}} = EventMap.toggle(element)
    end

    test "flips toggler from on to off" do
      element = el("dark_mode", "toggler", %{"is_toggled" => true})
      assert {:ok, {:toggle, "dark_mode", false}} = EventMap.toggle(element)
    end

    test "returns error for non-togglable widget" do
      assert {:error, msg} = EventMap.toggle(el("x", "text"))
      assert msg =~ "cannot toggle"
    end
  end

  # -- select/2 --

  describe "select/2" do
    test "returns select event for radio with group" do
      element = el("opt-a", "radio", %{"group" => "size"})
      assert {:ok, {:select, "size", "large"}} = EventMap.select(element, "large")
    end

    test "falls back to name prop for radio group" do
      element = el("opt-b", "radio", %{"name" => "colour"})
      assert {:ok, {:select, "colour", "red"}} = EventMap.select(element, "red")
    end

    test "returns select event for pick_list" do
      element = el("country", "pick_list")
      assert {:ok, {:select, "country", "NZ"}} = EventMap.select(element, "NZ")
    end

    test "returns select event for combo_box" do
      element = el("lang", "combo_box")
      assert {:ok, {:select, "lang", "Elixir"}} = EventMap.select(element, "Elixir")
    end

    test "returns error for non-selectable widget" do
      assert {:error, msg} = EventMap.select(el("x", "text"), "v")
      assert msg =~ "cannot select"
    end
  end

  # -- slide/2 --

  describe "slide/2" do
    test "returns slide event for slider" do
      assert {:ok, {:slide, "volume", 75}} = EventMap.slide(el("volume", "slider"), 75)
    end

    test "returns slide event for vertical_slider" do
      assert {:ok, {:slide, "pitch", 0.5}} =
               EventMap.slide(el("pitch", "vertical_slider"), 0.5)
    end

    test "returns error for non-slidable widget" do
      assert {:error, msg} = EventMap.slide(el("x", "button"), 42)
      assert msg =~ "cannot slide"
    end
  end
end
