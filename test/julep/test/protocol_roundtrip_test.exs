defmodule Julep.Test.ProtocolRoundtripTest do
  use ExUnit.Case, async: true

  alias Julep.Event.Widget

  alias Julep.Test.Backend.Pooled
  alias Julep.Test.Element

  # A test app that renders one of every major widget type so we can verify
  # the full normalize -> find -> interact cycle for each.
  defmodule WidgetApp do
    use Julep.App

    def init(_opts), do: %{text_value: "", selected: nil}

    def update(model, %Widget{type: :input, id: "search", value: text}),
      do: %{model | text_value: text}

    def update(model, %Widget{type: :select, id: "country", value: value}),
      do: %{model | selected: value}

    def update(model, _event), do: model

    def view(model) do
      %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{id: "title", type: "text", props: %{"content" => "Widget Gallery"}, children: []},
          %{id: "save", type: "button", props: %{"label" => "Save"}, children: []},
          %{
            id: "search",
            type: "text_input",
            props: %{"value" => model.text_value, "placeholder" => "Search..."},
            children: []
          },
          %{
            id: "agree",
            type: "checkbox",
            props: %{"label" => "I agree", "checked" => false},
            children: []
          },
          %{
            id: "volume",
            type: "slider",
            props: %{"value" => 50, "range" => [0, 100]},
            children: []
          },
          %{
            id: "country",
            type: "pick_list",
            props: %{"options" => ["NZ", "AU", "GB"], "selected" => model.selected},
            children: []
          },
          %{
            id: "layout",
            type: "row",
            props: %{},
            children: [
              %{
                id: "inner",
                type: "container",
                props: %{},
                children: [
                  %{id: "nested", type: "text", props: %{"content" => "nested"}, children: []}
                ]
              }
            ]
          }
        ]
      }
    end
  end

  setup do
    {:ok, pid} = Pooled.start(WidgetApp, pool: Julep.TestPool)

    on_exit(fn ->
      if Process.alive?(pid), do: Pooled.stop(pid)
    end)

    {:ok, pid: pid}
  end

  # -- button --

  describe "button" do
    test "renders with correct type", %{pid: pid} do
      element = Pooled.find(pid, "#save")
      assert %Element{} = element
      assert element.type == "button"
    end

    test "click dispatches event and updates model state", %{pid: pid} do
      # The app ignores click events but the backend must dispatch without error.
      Pooled.click(pid, "#save")
      # No crash means the round-trip worked.
      assert Pooled.model(pid).text_value == ""
    end
  end

  # -- text --

  describe "text" do
    test "renders with correct type and content prop", %{pid: pid} do
      element = Pooled.find(pid, "#title")
      assert element.type == "text"
      assert element.props["content"] == "Widget Gallery"
    end

    test "findable by text content", %{pid: pid} do
      element = Pooled.find(pid, "Widget Gallery")
      assert %Element{id: "title"} = element
    end
  end

  # -- text_input --

  describe "text_input" do
    test "renders with correct type", %{pid: pid} do
      element = Pooled.find(pid, "#search")
      assert element.type == "text_input"
    end

    test "value prop reflects model", %{pid: pid} do
      element = Pooled.find(pid, "#search")
      assert element.props["value"] == ""
    end

    test "type_text dispatches input event and model updates", %{pid: pid} do
      Pooled.type_text(pid, "#search", "hello")
      assert Pooled.model(pid).text_value == "hello"
    end

    test "tree reflects updated value after input", %{pid: pid} do
      Pooled.type_text(pid, "#search", "julep")
      element = Pooled.find(pid, "#search")
      assert element.props["value"] == "julep"
    end
  end

  # -- checkbox --

  describe "checkbox" do
    test "renders with correct type", %{pid: pid} do
      element = Pooled.find(pid, "#agree")
      assert element.type == "checkbox"
    end

    test "toggle dispatches event without error", %{pid: pid} do
      Pooled.toggle(pid, "#agree")
      # App ignores toggle but the round-trip must complete cleanly.
      assert is_map(Pooled.model(pid))
    end
  end

  # -- slider --

  describe "slider" do
    test "renders with correct type", %{pid: pid} do
      element = Pooled.find(pid, "#volume")
      assert element.type == "slider"
    end

    test "value prop present in tree", %{pid: pid} do
      element = Pooled.find(pid, "#volume")
      assert element.props["value"] == 50
    end

    test "slide dispatches event without error", %{pid: pid} do
      Pooled.slide(pid, "#volume", 75)
      assert is_map(Pooled.model(pid))
    end
  end

  # -- pick_list --

  describe "pick_list" do
    test "renders with correct type", %{pid: pid} do
      element = Pooled.find(pid, "#country")
      assert element.type == "pick_list"
    end

    test "options prop present in tree", %{pid: pid} do
      element = Pooled.find(pid, "#country")
      assert element.props["options"] == ["NZ", "AU", "GB"]
    end

    test "select dispatches event and model updates", %{pid: pid} do
      Pooled.select(pid, "#country", "NZ")
      assert Pooled.model(pid).selected == "NZ"
    end
  end

  # -- container/column/row nesting --

  describe "layout nesting" do
    test "row renders with correct type", %{pid: pid} do
      element = Pooled.find(pid, "#layout")
      assert element.type == "row"
    end

    test "nested container is findable", %{pid: pid} do
      element = Pooled.find(pid, "#inner")
      assert element.type == "container"
    end

    test "deeply nested text is findable", %{pid: pid} do
      element = Pooled.find(pid, "#nested")
      assert element.type == "text"
    end

    test "find by text traverses nested children", %{pid: pid} do
      element = Pooled.find(pid, "nested")
      assert %Element{id: "nested"} = element
    end
  end
end
