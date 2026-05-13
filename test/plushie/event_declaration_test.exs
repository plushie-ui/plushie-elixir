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
    event(:selected, value: :float)

    @impl true
    def handle_event(%{type: :click}, _state), do: {:emit, :selected, 42}
    def handle_event(_event, _state), do: :ignored

    @impl true
    def view(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  defmodule DataEventWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:data_event_widget)
    event(:moved, fields: [x: :float, y: :float])

    @impl true
    def handle_event(%{type: :click}, _state), do: {:emit, :moved, %{x: 10.0, y: 20.0}}
    def handle_event(_event, _state), do: :ignored

    @impl true
    def view(id, _props, _state) do
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
    def view(id, _props, _state) do
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
    def view(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  defmodule CustomTypeWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:custom_type_widget)
    event(:key_action, fields: [key: Plushie.Type.Key])

    @impl true
    def handle_event(_event, _state), do: :ignored

    @impl true
    def view(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  # -- Test widgets with do-block event declarations --------------------------

  defmodule DoBlockEventWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:do_block_event_widget)

    event :changed do
      field(:hue, :float)
      field(:saturation, :float)
    end

    @impl true
    def handle_event(%{type: :click}, _state),
      do: {:emit, :changed, %{hue: 180.0, saturation: 0.75}}

    def handle_event(_event, _state), do: :ignored

    @impl true
    def view(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  defmodule OptionalFieldWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:optional_field_widget)

    event :adjusted do
      field(:hue, :float)
      field(:saturation, :float)
      field(:modifier, :string, required: false)
    end

    @impl true
    def handle_event(%{type: :click, id: "with_mod"}, _state),
      do: {:emit, :adjusted, %{hue: 90.0, saturation: 0.5, modifier: "shift"}}

    def handle_event(%{type: :click}, _state),
      do: {:emit, :adjusted, %{hue: 90.0, saturation: 0.5}}

    def handle_event(_event, _state), do: :ignored

    @impl true
    def view(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  defmodule MissingRequiredFieldWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:missing_required_field_widget)

    event :color_pick do
      field(:hue, :float)
      field(:saturation, :float)
    end

    @impl true
    def handle_event(%{type: :click}, _state),
      do: {:emit, :color_pick, %{hue: 90.0}}

    def handle_event(_event, _state), do: :ignored

    @impl true
    def view(id, _props, _state) do
      import Plushie.UI

      canvas id, width: 1, height: 1 do
      end
    end
  end

  # -- Event spec generation --------------------------------------------------

  describe "event macro generates specs" do
    test "value event has carrier :value" do
      spec = ValueEventWidget.__event_spec__(:selected)
      assert %{carrier: :value, type: :float} = spec
    end

    test "data event has carrier :data with fields" do
      spec = DataEventWidget.__event_spec__(:moved)
      assert %{carrier: :value, fields: [x: :float, y: :float]} = spec
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
      assert %{carrier: :value, fields: [key: Plushie.Type.Key]} = spec
    end

    test "__events__/0 returns flat name list" do
      assert [:selected] = ValueEventWidget.__events__()
      assert [:moved] = DataEventWidget.__events__()
      assert [:cleared] = NoPayloadEventWidget.__events__()
      assert [:changed] = UnspecifiedValueWidget.__events__()
    end

    test "__event_specs__/0 returns all specs" do
      specs = ValueEventWidget.__event_specs__()
      assert [{:selected, %{carrier: :value, type: :float}}] = specs
    end

    test "__event_spec__/1 returns nil for unknown events" do
      assert nil == ValueEventWidget.__event_spec__(:nonexistent)
    end

    test "inline fields: form includes required list with all field names" do
      spec = DataEventWidget.__event_spec__(:moved)
      assert %{carrier: :value, fields: [x: :float, y: :float], required: [:x, :y]} = spec
    end
  end

  describe "event do-block with field macro" do
    test "do-block fields produce carrier :data spec" do
      spec = DoBlockEventWidget.__event_spec__(:changed)
      assert %{carrier: :value, fields: [hue: :float, saturation: :float]} = spec
    end

    test "do-block fields are all required by default" do
      spec = DoBlockEventWidget.__event_spec__(:changed)
      assert spec.required == [:hue, :saturation]
    end

    test "required: false excludes field from required list" do
      spec = OptionalFieldWidget.__event_spec__(:adjusted)
      assert %{carrier: :value} = spec
      assert :hue in spec.required
      assert :saturation in spec.required
      refute :modifier in spec.required
    end

    test "optional field is still declared in fields list" do
      spec = OptionalFieldWidget.__event_spec__(:adjusted)
      field_names = Keyword.keys(spec.fields)
      assert :hue in field_names
      assert :saturation in field_names
      assert :modifier in field_names
    end

    test "__events__/0 includes do-block declared events" do
      assert [:changed] = DoBlockEventWidget.__events__()
      assert [:adjusted] = OptionalFieldWidget.__events__()
    end

    test "unknown declarations in event blocks raise CompileError" do
      assert_raise CompileError,
                   ~r/expected `value type`, `fields \[\.\.\.\]`, or `fields do \.\.\. end`/,
                   fn ->
                     Code.compile_string("""
                     defmodule BadEventBlockWidget do
                       use Plushie.Widget

                       widget :bad_event_block

                       event :changed do
                         floater 42
                       end
                     end
                     """)
                   end
    end

    test "event blocks reject multiple payload declarations" do
      assert_raise CompileError, ~r/event block can declare only one payload/, fn ->
        Code.compile_string("""
        defmodule DuplicateEventPayloadWidget do
          use Plushie.Widget

          widget :duplicate_event_payload

          event :changed do
            value :string
            fields x: :float
          end
        end
        """)
      end
    end
  end

  describe "do-block emit routing" do
    alias Plushie.Widget.Handler

    test "do-block data event emits to data field" do
      click = %Plushie.Event.WidgetEvent{
        type: :click,
        id: "elem",
        scope: ["widget"],
        window_id: "main"
      }

      {{:emit, event}, _state} =
        Handler.invoke_handler(DoBlockEventWidget, click, %{}, "widget", "main")

      assert event.type == {:do_block_event_widget, :changed}
      assert event.value == %{hue: 180.0, saturation: 0.75}
    end

    test "optional field can be omitted from emitted data" do
      click = %Plushie.Event.WidgetEvent{
        type: :click,
        id: "elem",
        scope: ["widget"],
        window_id: "main"
      }

      {{:emit, event}, _state} =
        Handler.invoke_handler(OptionalFieldWidget, click, %{}, "widget", "main")

      assert event.type == {:optional_field_widget, :adjusted}
      assert event.value == %{hue: 90.0, saturation: 0.5}
    end

    test "optional field can be included in emitted data" do
      click = %Plushie.Event.WidgetEvent{
        type: :click,
        id: "with_mod",
        scope: ["widget"],
        window_id: "main"
      }

      {{:emit, event}, _state} =
        Handler.invoke_handler(OptionalFieldWidget, click, %{}, "widget", "main")

      assert event.type == {:optional_field_widget, :adjusted}
      assert event.value == %{hue: 90.0, saturation: 0.5, modifier: "shift"}
    end

    test "missing required field raises ArgumentError" do
      click = %Plushie.Event.WidgetEvent{
        type: :click,
        id: "elem",
        scope: ["widget"],
        window_id: "main"
      }

      assert_raise ArgumentError, ~r/missing required fields.*:saturation/, fn ->
        Handler.invoke_handler(MissingRequiredFieldWidget, click, %{}, "widget", "main")
      end
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
      assert event.value == %{x: 10.0, y: 20.0}
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
    end
  end

  # -- BuiltinSpecs -----------------------------------------------------------

  describe "BuiltinSpecs" do
    test "has spec for all builtin event types" do
      for type <-
            ~w(click input submit toggle select slide slide_release paste open close option_hovered key_binding link_click sort scrolled pane_focus_cycle)a do
        assert BuiltinSpecs.spec(type) != nil, "missing spec for #{type}"
      end
    end

    test "has specs for unified pointer event types" do
      for type <- ~w(press release move scroll enter exit double_click resize)a do
        assert BuiltinSpecs.spec(type) != nil, "missing spec for #{type}"
      end
    end

    test "press spec has pointer data fields" do
      spec = BuiltinSpecs.spec(:press)
      assert spec.carrier == :value
      field_names = Keyword.keys(spec.fields)
      assert :x in field_names
      assert :y in field_names
      assert :button in field_names
      assert :pointer in field_names
      assert :finger in field_names
      assert :modifiers in field_names
    end

    test "toggle spec has value :boolean" do
      assert %{carrier: :value, type: :boolean} = BuiltinSpecs.spec(:toggle)
    end

    test "sort spec has column field" do
      assert %{carrier: :value, fields: fields} = BuiltinSpecs.spec(:sort)
      assert Keyword.fetch!(fields, :column) == :string
    end

    test "key_press spec has parsed data fields" do
      spec = BuiltinSpecs.spec(:key_press)
      assert %{carrier: :value, fields: fields} = spec
      assert Keyword.fetch!(fields, :key) == Plushie.Type.Key
      assert Keyword.fetch!(fields, :modifiers) == Plushie.Type.KeyModifiers
    end
  end
end
