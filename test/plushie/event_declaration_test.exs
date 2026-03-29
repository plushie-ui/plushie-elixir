defmodule Plushie.EventDeclarationTest do
  @moduledoc """
  Tests for the typed event declaration DSL and built-in event specs.
  """

  use ExUnit.Case, async: true

  alias Plushie.Event.BuiltinSpecs

  # -- Test widgets with typed event declarations ----------------------------

  defmodule ValueEventWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:value_event_widget)
    event(:selected, value: :number)

    @impl true
    def handle_event(%{type: :click}, _state), do: {:emit, :selected, 42}
    def handle_event(_event, _state), do: :ignored

    @impl true
    def render(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  defmodule DataEventWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:data_event_widget)
    event(:moved, data: [x: :number, y: :number])

    @impl true
    def handle_event(%{type: :click}, _state), do: {:emit, :moved, %{x: 10.0, y: 20.0}}
    def handle_event(_event, _state), do: :ignored

    @impl true
    def render(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  defmodule NoPayloadEventWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:no_payload_event_widget)
    event(:cleared)

    @impl true
    def handle_event(_event, _state), do: :ignored

    @impl true
    def render(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  defmodule UnspecifiedValueWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:unspecified_value_widget)
    event(:changed, value: :any)

    @impl true
    def handle_event(_event, _state), do: :ignored

    @impl true
    def render(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  defmodule CustomTypeWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:custom_type_widget)
    event(:key_action, data: [key: Plushie.Type.Key])

    @impl true
    def handle_event(_event, _state), do: :ignored

    @impl true
    def render(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  # -- Event spec generation --------------------------------------------------

  describe "event macro generates specs" do
    test "value event has carrier :value" do
      spec = ValueEventWidget.__event_spec__(:selected)
      assert %{carrier: :value, type: :number} = spec
    end

    test "data event has carrier :data with fields" do
      spec = DataEventWidget.__event_spec__(:moved)
      assert %{carrier: :data, fields: [x: :number, y: :number]} = spec
    end

    test "no-payload event has carrier :none" do
      spec = NoPayloadEventWidget.__event_spec__(:cleared)
      assert %{carrier: :none} = spec
    end

    test "value: :any allows any value" do
      spec = UnspecifiedValueWidget.__event_spec__(:changed)
      assert %{carrier: :value, type: :any} = spec
    end

    test "custom module type is preserved in spec" do
      spec = CustomTypeWidget.__event_spec__(:key_action)
      assert %{carrier: :data, fields: [key: Plushie.Type.Key]} = spec
    end

    test "__events__/0 returns flat name list" do
      assert [:selected] = ValueEventWidget.__events__()
      assert [:moved] = DataEventWidget.__events__()
      assert [:cleared] = NoPayloadEventWidget.__events__()
      assert [:changed] = UnspecifiedValueWidget.__events__()
    end

    test "__event_specs__/0 returns all specs" do
      specs = ValueEventWidget.__event_specs__()
      assert [{:selected, %{carrier: :value, type: :number}}] = specs
    end

    test "__event_spec__/1 returns nil for unknown events" do
      assert nil == ValueEventWidget.__event_spec__(:nonexistent)
    end
  end

  # -- Canvas widget emit routing --------------------------------------------

  describe "emit routing with specs" do
    alias Plushie.Widget.Handler

    test "value-spec event puts data in value field" do
      click = %Plushie.Event.WidgetEvent{
        type: :click,
        id: "elem",
        scope: ["widget"],
        window_id: "main"
      }

      {{:emit, event}, _state} =
        Handler.invoke_handler(ValueEventWidget, click, %{}, "widget", "main")

      assert event.type == {:value_event_widget, :selected}
      assert event.value == 42
      assert event.data == nil
    end

    test "data-spec event puts map in data field with atom keys" do
      click = %Plushie.Event.WidgetEvent{
        type: :click,
        id: "elem",
        scope: ["widget"],
        window_id: "main"
      }

      {{:emit, event}, _state} =
        Handler.invoke_handler(DataEventWidget, click, %{}, "widget", "main")

      assert event.type == {:data_event_widget, :moved}
      assert event.data == %{x: 10.0, y: 20.0}
      assert event.value == nil
    end

    test "built-in event type uses builtin spec for routing" do
      # ThemeToggle emits :toggle (builtin) with a boolean value.
      # The builtin spec says value: :boolean, so data goes in value field.
      click = %Plushie.Event.WidgetEvent{
        type: :click,
        id: "switch",
        scope: ["theme-toggle"],
        window_id: "main"
      }

      {{:emit, event}, _state} =
        Handler.invoke_handler(
          ThemeToggle,
          click,
          %{progress: 0.0, target: 0.0},
          "theme-toggle",
          "main"
        )

      assert event.type == :toggle
      assert event.value == true
      assert event.data == nil
    end
  end

  # -- BuiltinSpecs -----------------------------------------------------------

  describe "BuiltinSpecs" do
    test "has spec for all builtin event types" do
      for type <- ~w(click input submit toggle select slide slide_release paste open close)a do
        assert BuiltinSpecs.spec(type) != nil, "missing spec for #{type}"
      end
    end

    test "canvas_internal? identifies canvas-internal types" do
      assert BuiltinSpecs.canvas_internal?(:canvas_element_enter)
      assert BuiltinSpecs.canvas_internal?(:canvas_element_key_press)
      assert BuiltinSpecs.canvas_internal?(:canvas_focused)
      assert BuiltinSpecs.canvas_internal?(:canvas_group_blurred)
    end

    test "canvas_internal? rejects non-canvas types" do
      refute BuiltinSpecs.canvas_internal?(:click)
      refute BuiltinSpecs.canvas_internal?(:toggle)
      refute BuiltinSpecs.canvas_internal?(:input)
    end

    test "toggle spec has value :boolean" do
      assert %{carrier: :value, type: :boolean} = BuiltinSpecs.spec(:toggle)
    end

    test "canvas_element_key_press spec has parsed data fields" do
      spec = BuiltinSpecs.spec(:canvas_element_key_press)
      assert %{carrier: :data, fields: fields} = spec
      assert Keyword.fetch!(fields, :key) == Plushie.Type.Key
      assert Keyword.fetch!(fields, :modifiers) == Plushie.Type.KeyModifiers
    end
  end
end
