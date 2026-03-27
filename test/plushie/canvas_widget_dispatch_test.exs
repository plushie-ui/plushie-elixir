defmodule Plushie.CanvasWidgetDispatchTest do
  @moduledoc """
  Tests for canvas_widget event dispatch through the scope chain.

  Uses minimal test widgets to verify the captured/ignored model
  without depending on example widgets. Each test widget returns
  a specific handle_event result to validate the dispatch behavior.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Plushie.Extension.CanvasWidget
  alias Plushie.Runtime.CanvasWidgets

  # -- Minimal test widgets ----------------------------------------------------

  defmodule IgnoredWidget do
    @moduledoc false
    use Plushie.Extension, :canvas_widget
    widget(:ignored_widget)

    @impl true
    def handle_event(_event, _state), do: :ignored

    @impl true
    def render(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 10, height: 10 do
      end
    end
  end

  defmodule ConsumedWidget do
    @moduledoc false
    use Plushie.Extension, :canvas_widget
    widget(:consumed_widget)

    @impl true
    def handle_event(_event, _state), do: :consumed

    @impl true
    def render(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 10, height: 10 do
      end
    end
  end

  defmodule EmitWidget do
    @moduledoc false
    use Plushie.Extension, :canvas_widget
    widget(:emit_widget)
    events([:activated])

    @impl true
    def handle_event(%{type: type} = _event, state) when type in [:click, :press] do
      {:emit, :activated, %{source: "emit_widget"}, state}
    end

    def handle_event(_event, _state), do: :ignored

    @impl true
    def render(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 10, height: 10 do
      end
    end
  end

  defmodule StateWidget do
    @moduledoc false
    use Plushie.Extension, :canvas_widget
    widget(:state_widget)
    state(counter: 0)

    @impl true
    def handle_event(%{type: :click}, state) do
      {:update_state, %{state | counter: state.counter + 1}}
    end

    def handle_event(_event, _state), do: :ignored

    @impl true
    def render(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 10, height: 10 do
      end
    end
  end

  # -- invoke_handler (single widget) ------------------------------------------

  describe "invoke_handler/4 with :ignored" do
    test "returns :ignored action and unchanged state" do
      {action, state} =
        CanvasWidget.invoke_handler(IgnoredWidget, click_event("test"), %{}, "test")

      assert action == :ignored
      assert state == %{}
    end
  end

  describe "invoke_handler/4 with :consumed" do
    test "returns :consumed action and unchanged state" do
      {action, state} =
        CanvasWidget.invoke_handler(ConsumedWidget, click_event("test"), %{}, "test")

      assert action == :consumed
      assert state == %{}
    end
  end

  describe "invoke_handler/4 with {:emit, ...}" do
    test "returns {:emit, widget_event} with transformed event" do
      {{:emit, widget_event}, _state} =
        CanvasWidget.invoke_handler(EmitWidget, click_event("elem", ["widget"]), %{}, "widget")

      assert widget_event.type == {:emit_widget, :activated}
      assert widget_event.data["source"] == "emit_widget"
      assert widget_event.id == "widget"
    end
  end

  describe "invoke_handler/4 with {:update_state, ...}" do
    test "returns :consumed with updated state" do
      {action, state} =
        CanvasWidget.invoke_handler(StateWidget, click_event("test"), %{counter: 0}, "test")

      assert action == :consumed
      assert state.counter == 1
    end
  end

  # -- CanvasWidgets.dispatch_event (scope chain) ------------------------------

  describe "scope chain dispatch with empty registry" do
    test "event passes through unchanged" do
      {event, registry} =
        CanvasWidgets.dispatch_event(%{}, click_event("btn", ["form"]))

      assert event.type == :click
      assert event.id == "btn"
      assert registry == %{}
    end
  end

  describe "scope chain dispatch with :ignored widget" do
    test "event passes through when widget ignores" do
      registry = %{
        {nil, "parent"} => %{module: IgnoredWidget, state: %{}}
      }

      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, click_event("btn", ["parent"]))

      # Event reaches app.update/2 unchanged
      assert event.type == :click
      assert event.id == "btn"
    end
  end

  describe "scope chain dispatch with :consumed widget" do
    test "event is suppressed" do
      registry = %{
        {nil, "parent"} => %{module: ConsumedWidget, state: %{}}
      }

      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, click_event("btn", ["parent"]))

      assert event == nil
    end
  end

  describe "scope chain dispatch with :emit widget" do
    test "event is transformed" do
      registry = %{
        {nil, "widget"} => %{module: EmitWidget, state: %{}}
      }

      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, click_event("elem", ["widget"]))

      assert event.type == {:emit_widget, :activated}
      assert event.data["source"] == "emit_widget"
    end
  end

  describe "scope chain dispatch with :update_state widget" do
    test "event is consumed and state is updated" do
      registry = %{
        {nil, "widget"} => %{module: StateWidget, state: %{counter: 5}}
      }

      {event, registry} =
        CanvasWidgets.dispatch_event(registry, click_event("elem", ["widget"]))

      assert event == nil
      assert registry[{nil, "widget"}].state.counter == 6
    end
  end

  # -- Hierarchical dispatch ---------------------------------------------------

  describe "hierarchical scope chain" do
    test ":ignored bubbles to parent" do
      # Child ignores, parent consumes
      registry = %{
        {nil, "parent/child"} => %{module: IgnoredWidget, state: %{}},
        {nil, "parent"} => %{module: ConsumedWidget, state: %{}}
      }

      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, click_event("elem", ["child", "parent"]))

      # Child ignored → parent consumed → nil
      assert event == nil
    end

    test ":emit from child reaches parent" do
      # Child emits, parent sees the emitted event
      registry = %{
        {nil, "parent/child"} => %{module: EmitWidget, state: %{}},
        {nil, "parent"} => %{module: ConsumedWidget, state: %{}}
      }

      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, click_event("elem", ["child", "parent"]))

      # Child emits :activated → parent consumes it → nil
      assert event == nil
    end

    test ":emit from child passes through :ignored parent to app" do
      # Child emits, parent ignores the emitted event
      registry = %{
        {nil, "parent/child"} => %{module: EmitWidget, state: %{}},
        {nil, "parent"} => %{module: IgnoredWidget, state: %{}}
      }

      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, click_event("elem", ["child", "parent"]))

      # Child emits {:emit_widget, :activated} → parent ignores → event reaches app
      assert event.type == {:emit_widget, :activated}
    end

    test "non-widget scope elements are skipped" do
      # "container" is not a canvas_widget, only "parent" is
      registry = %{
        {nil, "parent"} => %{module: ConsumedWidget, state: %{}}
      }

      {event, _registry} =
        CanvasWidgets.dispatch_event(
          registry,
          click_event("elem", ["container", "parent"])
        )

      # "container" not in registry → skipped → "parent" consumes
      assert event == nil
    end
  end

  # -- derive_registry ---------------------------------------------------------

  describe "derive_registry/1" do
    test "extracts widget entries from tree meta" do
      tree = %{
        id: "root",
        type: "window",
        props: %{},
        children: [
          %{
            id: "picker",
            type: "canvas",
            props: %{},
            children: [],
            meta: %{
              __canvas_widget__: EmitWidget,
              __canvas_widget_state__: %{counter: 3},
              __canvas_widget_props__: %{color: "red"}
            }
          }
        ]
      }

      registry = CanvasWidgets.derive_registry(tree)
      assert Map.has_key?(registry, {"root", "picker"})
      assert registry[{"root", "picker"}].module == EmitWidget
      assert registry[{"root", "picker"}].state.counter == 3
      assert registry[{"root", "picker"}].props.color == "red"
    end

    test "returns empty map for nil tree" do
      assert CanvasWidgets.derive_registry(nil) == %{}
    end

    test "returns empty map for tree without canvas_widgets" do
      tree = %{id: "root", type: "window", props: %{}, children: []}
      assert CanvasWidgets.derive_registry(tree) == %{}
    end
  end

  # -- Direct-target dispatch (canvas events) -----------------------------------

  describe "direct-target dispatch (canvas press/move/release)" do
    test "canvas event with empty scope targets widget by full ID" do
      registry = %{
        {nil, "picker"} => %{module: ConsumedWidget, state: %{}}
      }

      # Canvas press: id = "picker", scope = []
      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, canvas_event("picker", []))

      assert event == nil
    end

    test "canvas event with scope reconstructs full scoped ID" do
      registry = %{
        {nil, "form/picker"} => %{module: ConsumedWidget, state: %{}}
      }

      # Canvas press on "form/picker": id = "picker", scope = ["form"]
      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, canvas_event("picker", ["form"]))

      assert event == nil
    end

    test "does not match wrong widget with same local ID" do
      # Root-level "submit" and scoped "form/submit" both exist.
      # A canvas event for "form/submit" must not match root "submit".
      registry = %{
        {nil, "submit"} => %{module: EmitWidget, state: %{}},
        {nil, "form/submit"} => %{module: ConsumedWidget, state: %{}}
      }

      # Event for "form/submit": id = "submit", scope = ["form"]
      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, canvas_event("submit", ["form"]))

      # Should match "form/submit" (ConsumedWidget) → nil, NOT "submit" (EmitWidget)
      assert event == nil
    end

    test "falls through when no widget matches the full path" do
      registry = %{
        {nil, "other"} => %{module: ConsumedWidget, state: %{}}
      }

      event = canvas_event("picker", [])
      {result, _registry} = CanvasWidgets.dispatch_event(registry, event)

      # No match → event passes through unchanged
      assert result == event
    end

    test "direct canvas event targets the child widget before the parent" do
      registry = %{
        {nil, "parent/child"} => %{module: ConsumedWidget, state: %{}},
        {nil, "parent"} => %{module: IgnoredWidget, state: %{}}
      }

      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, canvas_event("child", ["parent"]))

      assert event == nil
    end

    test "direct canvas emit keeps the widget id and parent scope" do
      registry = %{
        {nil, "form/picker"} => %{module: EmitWidget, state: %{}}
      }

      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, canvas_event("picker", ["form"]))

      assert event.type == {:emit_widget, :activated}
      assert event.id == "picker"
      assert event.scope == ["form"]
      assert event.window_id == nil
    end

    test "windowed direct canvas event stays in its own window" do
      registry = %{
        {"main", "picker"} => %{module: EmitWidget, state: %{}},
        {"other", "picker"} => %{module: ConsumedWidget, state: %{}}
      }

      {event, _registry} =
        CanvasWidgets.dispatch_event(registry, canvas_event("picker", [], "main"))

      assert event.type == {:emit_widget, :activated}
      assert event.id == "picker"
      assert event.window_id == "main"
    end
  end

  # -- Raising widget for error-handling tests ----------------------------------

  defmodule RaisingWidget do
    @moduledoc false
    use Plushie.Extension, :canvas_widget
    widget(:raising_widget)

    @impl true
    def handle_event(%{type: :click}, _state) do
      raise "kaboom from RaisingWidget"
    end

    def handle_event(_event, _state), do: :ignored

    @impl true
    def render(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 10, height: 10 do
      end
    end
  end

  # -- Error handling in dispatch chain ----------------------------------------

  describe "error handling in dispatch chain" do
    test "raising widget is treated as :ignored and chain continues" do
      registry = %{
        {nil, "widget"} => %{module: RaisingWidget, state: %{}}
      }

      log =
        capture_log(fn ->
          {event, _registry} =
            CanvasWidgets.dispatch_event(registry, click_event("elem", ["widget"]))

          # RaisingWidget raises on :click -> treated as :ignored -> event passes through
          assert event.type == :click
          assert event.id == "elem"
        end)

      assert log =~ "kaboom from RaisingWidget"
    end

    test "raising child is :ignored, parent still captures" do
      registry = %{
        {nil, "parent/child"} => %{module: RaisingWidget, state: %{}},
        {nil, "parent"} => %{module: ConsumedWidget, state: %{}}
      }

      log =
        capture_log(fn ->
          {event, _registry} =
            CanvasWidgets.dispatch_event(registry, click_event("elem", ["child", "parent"]))

          # Child raises (treated as :ignored) -> parent consumes -> nil
          assert event == nil
        end)

      assert log =~ "kaboom from RaisingWidget"
    end
  end

  # -- Helpers -----------------------------------------------------------------

  defp click_event(id, scope \\ []) do
    %Plushie.Event.WidgetEvent{type: :click, id: id, scope: scope}
  end

  defp canvas_event(id, scope, window_id \\ nil) do
    %Plushie.Event.Canvas{
      type: :press,
      id: id,
      scope: scope,
      window_id: window_id,
      x: 100.0,
      y: 100.0,
      button: "left"
    }
  end
end
