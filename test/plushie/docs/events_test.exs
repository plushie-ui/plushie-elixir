defmodule Plushie.Docs.EventsTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.{
    AsyncEvent,
    EffectEvent,
    ImeEvent,
    KeyEvent,
    ModifiersEvent,
    StreamEvent,
    SystemEvent,
    TimerEvent,
    WidgetEvent,
    WindowEvent
  }

  alias Plushie.Effect.Result

  # -- Widget events -----------------------------------------------------------

  test "events_widget_click_construct_test" do
    event = %WidgetEvent{type: :click, id: "save", scope: []}
    assert event.id == "save"
    assert event.scope == []
  end

  test "events_widget_click_match_test" do
    event = %WidgetEvent{type: :click, id: "save", scope: []}
    assert match?(%WidgetEvent{type: :click, id: "save"}, event)
  end

  test "events_widget_click_scope_test" do
    event = %WidgetEvent{type: :click, id: "save", scope: ["form"]}
    assert match?(%WidgetEvent{type: :click, id: "save", scope: ["form"]}, event)
  end

  test "events_widget_input_match_test" do
    event = %WidgetEvent{type: :input, id: "search", scope: [], value: "hello"}

    assert match?(%WidgetEvent{type: :input, id: "search"}, event)
    assert event.value == "hello"
  end

  test "events_widget_submit_match_test" do
    event = %WidgetEvent{type: :submit, id: "search", scope: [], value: "query"}

    assert match?(%WidgetEvent{type: :submit, id: "search"}, event)
    assert event.value == "query"
  end

  test "events_widget_toggle_match_test" do
    event = %WidgetEvent{type: :toggle, id: "dark_mode", scope: [], value: true}

    assert match?(%WidgetEvent{type: :toggle, id: "dark_mode"}, event)
    assert event.value == true
  end

  test "events_widget_select_match_test" do
    event = %WidgetEvent{type: :select, id: "theme_picker", scope: [], value: "nord"}

    assert match?(%WidgetEvent{type: :select, id: "theme_picker"}, event)
    assert event.value == "nord"
  end

  test "events_widget_slide_match_test" do
    event = %WidgetEvent{type: :slide, id: "volume", scope: [], value: 75.0}

    assert match?(%WidgetEvent{type: :slide, id: "volume"}, event)
    assert event.value == 75.0
  end

  test "events_widget_slide_release_match_test" do
    event = %WidgetEvent{type: :slide_release, id: "volume", scope: [], value: 75.0}

    assert match?(%WidgetEvent{type: :slide_release, id: "volume"}, event)
    assert event.value == 75.0
  end

  test "events_widget_key_binding_match_test" do
    event = %WidgetEvent{type: :key_binding, id: "editor", scope: [], value: "save"}

    assert match?(%WidgetEvent{type: :key_binding, id: "editor", value: "save"}, event)
  end

  test "events_widget_scroll_match_test" do
    event = %WidgetEvent{
      type: :scroll,
      id: "log_view",
      scope: [],
      value: %{
        absolute_x: 0.0,
        absolute_y: 150.0,
        relative_x: 0.0,
        relative_y: 0.75,
        bounds: {400.0, 300.0},
        content_bounds: {400.0, 600.0}
      }
    }

    assert match?(%WidgetEvent{type: :scroll, id: "log_view"}, event)
    assert event.value.relative_y == 0.75
    refute event.value.relative_y >= 0.99
  end

  test "events_widget_paste_match_test" do
    event = %WidgetEvent{type: :paste, id: "url_input", scope: [], value: " text "}

    assert match?(%WidgetEvent{type: :paste, id: "url_input"}, event)
    assert event.value == " text "
  end

  test "events_widget_option_hovered_match_test" do
    event = %WidgetEvent{type: :option_hovered, id: "search", scope: [], value: "opt1"}

    assert match?(%WidgetEvent{type: :option_hovered, id: "search"}, event)
    assert event.value == "opt1"
  end

  test "events_widget_open_close_match_test" do
    open = %WidgetEvent{type: :open, id: "country_picker", scope: []}
    close = %WidgetEvent{type: :close, id: "country_picker", scope: []}

    assert match?(%WidgetEvent{type: :open, id: "country_picker"}, open)
    assert match?(%WidgetEvent{type: :close, id: "country_picker"}, close)
  end

  test "events_widget_sort_match_test" do
    event = %WidgetEvent{type: :sort, id: "users", scope: [], value: "name"}

    assert match?(%WidgetEvent{type: :sort, id: "users"}, event)
    assert event.value == "name"
  end

  # -- Pointer events (mouse area + canvas unified) ----------------------------

  test "events_pointer_enter_match_test" do
    event = %WidgetEvent{type: :enter, id: "hover_zone", scope: []}

    assert match?(%WidgetEvent{type: :enter, id: "hover_zone"}, event)
  end

  test "events_pointer_move_match_test" do
    event = %WidgetEvent{
      type: :move,
      id: "canvas_area",
      scope: [],
      value: %{x: 10.0, y: 20.0, pointer: :mouse}
    }

    assert match?(%WidgetEvent{type: :move, id: "canvas_area"}, event)
    assert event.value.x == 10.0
    assert event.value.y == 20.0
  end

  test "events_pointer_press_match_test" do
    event = %WidgetEvent{
      type: :press,
      id: "draw_area",
      scope: [],
      value: %{x: 42.0, y: 100.0, button: :left, pointer: :mouse}
    }

    assert match?(
             %WidgetEvent{type: :press, id: "draw_area", value: %{button: :left}},
             event
           )

    assert event.value.x == 42.0
    assert event.value.y == 100.0
  end

  test "events_pointer_move_canvas_match_test" do
    event = %WidgetEvent{
      type: :move,
      id: "draw_area",
      scope: [],
      value: %{x: 5.0, y: 10.0, pointer: :mouse}
    }

    assert match?(%WidgetEvent{type: :move, id: "draw_area"}, event)
    assert event.value.x == 5.0
    assert event.value.y == 10.0
  end

  test "events_canvas_element_click_is_scoped_click_test" do
    # Canvas element clicks arrive as regular :click events with scope
    event = %WidgetEvent{
      type: :click,
      id: "bar-jan",
      scope: ["chart"],
      value: %{x: 15.0, y: 70.0, button: :left}
    }

    assert match?(%WidgetEvent{type: :click, id: "bar-jan", scope: ["chart" | _]}, event)
  end

  # -- Sensor events -----------------------------------------------------------

  test "events_resize_match_test" do
    event = %WidgetEvent{
      type: :resize,
      id: "content_area",
      scope: [],
      value: %{width: 800.0, height: 600.0}
    }

    assert match?(%WidgetEvent{type: :resize, id: "content_area"}, event)
    assert event.value.width == 800.0
    assert event.value.height == 600.0
  end

  # -- PaneGrid events ---------------------------------------------------------

  test "events_pane_resized_match_test" do
    event = %WidgetEvent{
      type: :pane_resized,
      id: "editor",
      scope: [],
      value: %{split: "split_1", ratio: 0.5}
    }

    assert match?(%WidgetEvent{type: :pane_resized, id: "editor"}, event)
    assert event.value.ratio == 0.5
  end

  test "events_pane_clicked_match_test" do
    event = %WidgetEvent{type: :pane_clicked, id: "editor", scope: [], value: %{pane: "left"}}

    assert match?(%WidgetEvent{type: :pane_clicked, id: "editor"}, event)
  end

  # -- Keyboard events ---------------------------------------------------------

  test "events_key_press_cmd_s_match_test" do
    event = %KeyEvent{
      type: :press,
      key: "s",
      modified_key: "s",
      modifiers: %Plushie.KeyModifiers{command: true},
      physical_key: :key_s,
      location: :standard,
      text: "s",
      repeat: false,
      captured: false
    }

    assert match?(%KeyEvent{type: :press, key: "s", modifiers: %{command: true}}, event)
  end

  test "events_key_press_escape_match_test" do
    event = %KeyEvent{
      type: :press,
      key: :escape,
      modified_key: :escape,
      modifiers: %Plushie.KeyModifiers{},
      physical_key: :escape,
      location: :standard,
      text: nil,
      repeat: false,
      captured: false
    }

    assert match?(%KeyEvent{type: :press, key: :escape}, event)
  end

  test "events_key_press_physical_key_match_test" do
    event = %KeyEvent{
      type: :press,
      key: "w",
      modified_key: "w",
      modifiers: %Plushie.KeyModifiers{},
      physical_key: :key_w,
      location: :standard,
      text: "w",
      repeat: false,
      captured: false
    }

    assert match?(%KeyEvent{type: :press, physical_key: :key_w}, event)
  end

  test "events_key_press_text_field_match_test" do
    event = %KeyEvent{
      type: :press,
      key: "a",
      modified_key: "a",
      modifiers: %Plushie.KeyModifiers{},
      physical_key: :key_a,
      location: :standard,
      text: "a",
      repeat: false,
      captured: false
    }

    assert is_binary(event.text)
    assert event.text == "a"
  end

  test "events_modifiers_construct_test" do
    mods = %Plushie.KeyModifiers{
      shift: true,
      ctrl: false,
      alt: false,
      logo: false,
      command: false
    }

    assert mods.shift == true
    assert mods.ctrl == false
  end

  # -- IME events --------------------------------------------------------------

  test "events_ime_preedit_match_test" do
    event = %ImeEvent{type: :preedit, text: "compose", cursor: {0, 7}}

    assert event.text == "compose"
    assert event.cursor == {0, 7}
  end

  test "events_ime_commit_match_test" do
    event = %ImeEvent{type: :commit, text: "final"}

    assert event.text == "final"
  end

  # -- Pointer events (subscription) --------------------------------------------

  test "events_pointer_moved_match_test" do
    event = %WidgetEvent{
      type: :move,
      id: "main",
      value: %{x: 100.0, y: 200.0, pointer: :mouse, captured: false}
    }

    assert event.value.x == 100.0
    assert event.value.y == 200.0
    assert event.value.pointer == :mouse
  end

  test "events_pointer_button_pressed_match_test" do
    event = %WidgetEvent{
      type: :press,
      id: "main",
      value: %{button: :left, pointer: :mouse, captured: false}
    }

    assert match?(%WidgetEvent{type: :press, value: %{button: :left}}, event)
  end

  test "events_touch_pressed_match_test" do
    event = %WidgetEvent{
      type: :press,
      id: "main",
      value: %{pointer: :touch, finger: 0, x: 50.0, y: 75.0, button: :left, captured: false}
    }

    assert event.value.x == 50.0
    assert event.value.y == 75.0
    assert event.value.pointer == :touch
  end

  # -- Modifier state events ---------------------------------------------------

  test "events_modifiers_changed_match_test" do
    event = %ModifiersEvent{
      modifiers: %Plushie.KeyModifiers{
        shift: true,
        ctrl: false,
        alt: false,
        logo: false,
        command: false
      },
      captured: false
    }

    assert event.modifiers.shift == true
  end

  # -- Window events -----------------------------------------------------------

  test "events_window_close_requested_match_test" do
    event = %WindowEvent{type: :close_requested, window_id: "main"}

    assert match?(%WindowEvent{type: :close_requested, window_id: "main"}, event)
  end

  test "events_window_resized_match_test" do
    event = %WindowEvent{type: :resized, window_id: "main", width: 800.0, height: 600.0}

    assert match?(%WindowEvent{type: :resized, window_id: "main"}, event)
  end

  test "events_window_file_drag_drop_match_test" do
    hovered = %WindowEvent{type: :file_hovered, window_id: "main", path: "/foo.txt"}
    dropped = %WindowEvent{type: :file_dropped, window_id: "main", path: "/foo.txt"}
    left = %WindowEvent{type: :files_hovered_left, window_id: "main"}

    assert match?(%WindowEvent{type: :file_hovered, window_id: "main"}, hovered)
    assert hovered.path == "/foo.txt"

    assert match?(%WindowEvent{type: :file_dropped, window_id: "main"}, dropped)
    assert dropped.path == "/foo.txt"

    assert match?(%WindowEvent{type: :files_hovered_left, window_id: "main"}, left)
  end

  # -- System events -----------------------------------------------------------

  test "events_animation_frame_construct_test" do
    event = %SystemEvent{type: :animation_frame, value: 12_345}

    assert event.value == 12_345
  end

  test "events_theme_changed_construct_test" do
    event = %SystemEvent{type: :theme_changed, value: "dark"}

    assert event.value == "dark"
  end

  # -- Timer events ------------------------------------------------------------

  test "events_timer_tick_match_test" do
    event = %TimerEvent{tag: :tick, timestamp: 1_000_000}

    assert match?(%TimerEvent{tag: :tick}, event)
    assert event.timestamp == 1_000_000
  end

  # -- Command result events ---------------------------------------------------

  test "events_async_result_ok_match_test" do
    event = %AsyncEvent{tag: :data_loaded, result: {:ok, "hello"}}

    assert match?(%AsyncEvent{tag: :data_loaded, result: {:ok, _}}, event)
  end

  test "events_async_result_error_match_test" do
    event = %AsyncEvent{tag: :data_loaded, result: {:error, "fail"}}

    assert match?(%AsyncEvent{tag: :data_loaded, result: {:error, _}}, event)
  end

  test "events_stream_value_match_test" do
    event = %StreamEvent{tag: :file_import, value: 42}

    assert match?(%StreamEvent{tag: :file_import}, event)
  end

  # -- Effect result events ----------------------------------------------------

  test "events_effect_response_ok_match_test" do
    event = %EffectEvent{tag: :open, result: %Result.FileOpened{path: "/tmp/file.ex"}}

    assert match?(%EffectEvent{tag: :open, result: %Result.FileOpened{}}, event)
  end

  test "events_effect_response_cancelled_match_test" do
    event = %EffectEvent{tag: :open, result: %Result.Cancelled{}}

    assert match?(%EffectEvent{tag: :open, result: %Result.Cancelled{}}, event)
  end

  test "events_effect_response_error_match_test" do
    event = %EffectEvent{tag: :open, result: %Result.Error{message: "err"}}

    assert match?(%EffectEvent{result: %Result.Error{}}, event)
  end

  # -- Pattern matching tips ---------------------------------------------------

  test "events_pattern_prefix_match_test" do
    event = %WidgetEvent{type: :click, id: "nav:settings", scope: []}

    assert match?(%WidgetEvent{type: :click, id: "nav:" <> _}, event)

    %WidgetEvent{type: :click, id: "nav:" <> section} = event
    assert section == "settings"
  end

  test "events_pattern_toggle_prefix_match_test" do
    event = %WidgetEvent{type: :toggle, id: "setting:theme", scope: [], value: true}

    %WidgetEvent{type: :toggle, id: "setting:" <> key, value: value} = event
    assert key == "theme"
    assert value == true
  end

  # -- Scope matching ----------------------------------------------------------

  test "events_scope_sidebar_match_test" do
    event = %WidgetEvent{type: :click, id: "save", scope: ["sidebar"]}

    assert match?(%WidgetEvent{type: :click, id: "save", scope: ["sidebar" | _]}, event)
  end

  test "events_scope_main_match_test" do
    event = %WidgetEvent{type: :click, id: "save", scope: ["main"]}

    assert match?(%WidgetEvent{type: :click, id: "save", scope: ["main" | _]}, event)
  end

  test "events_catch_all_test" do
    event = %WidgetEvent{type: :click, id: "unknown", scope: []}

    result =
      case event do
        %WidgetEvent{type: :click, id: "save"} -> "save"
        _ -> "fallback"
      end

    assert result == "fallback"
  end
end
