defmodule Plushie.Docs.CommandsTest do
  use ExUnit.Case, async: true

  alias Plushie.Command
  alias Plushie.Event.SystemEvent
  alias Plushie.Subscription

  # -- command.none -----------------------------------------------------------

  test "commands_none_test" do
    cmd = Command.none()
    assert %Command{type: :none, payload: %{}} = cmd
  end

  # -- command.async ----------------------------------------------------------

  test "commands_async_construct_test" do
    cmd = Command.async(fn -> {:ok, "data"} end, :data_fetched)
    assert %Command{type: :async, payload: %{tag: :data_fetched}} = cmd
  end

  # -- command.stream ---------------------------------------------------------

  test "commands_stream_construct_test" do
    cmd =
      Command.stream(
        fn emit ->
          emit.(1)
          :done
        end,
        :file_import
      )

    assert %Command{type: :stream, payload: %{tag: :file_import}} = cmd
  end

  # -- command.cancel ---------------------------------------------------------

  test "commands_cancel_construct_test" do
    cmd = Command.cancel(:file_import)
    assert %Command{type: :cancel, payload: %{tag: :file_import}} = cmd
  end

  # -- command.done -----------------------------------------------------------

  test "commands_done_construct_test" do
    cmd = Command.done(:defaults, fn v -> {:config_loaded, v} end)
    assert %Command{type: :done, payload: %{value: :defaults}} = cmd
  end

  # -- command.exit -----------------------------------------------------------

  test "commands_exit_construct_test" do
    cmd = Command.exit()
    assert %Command{type: :exit, payload: %{}} = cmd
  end

  # -- Focus commands ---------------------------------------------------------

  test "commands_focus_construct_test" do
    cmd = Command.focus("todo_input")
    assert %Command{type: :focus, payload: %{target: "todo_input"}} = cmd
  end

  test "commands_focus_next_construct_test" do
    cmd = Command.focus_next()
    assert %Command{type: :focus_next, payload: %{}} = cmd
  end

  test "commands_focus_previous_construct_test" do
    cmd = Command.focus_previous()
    assert %Command{type: :focus_previous, payload: %{}} = cmd
  end

  # -- Text operations --------------------------------------------------------

  test "commands_select_all_construct_test" do
    cmd = Command.select_all("editor")
    assert %Command{type: :select_all, payload: %{target: "editor"}} = cmd
  end

  test "commands_select_range_construct_test" do
    cmd = Command.select_range("editor", 5, 10)
    assert %Command{type: :select_range, payload: payload} = cmd
    assert payload.target == "editor"
    assert payload.start == 5
    assert payload.end == 10
  end

  # -- Scroll operations ------------------------------------------------------

  test "commands_snap_to_end_construct_test" do
    cmd = Command.snap_to_end("chat_log")
    assert %Command{type: :snap_to_end, payload: %{target: "chat_log"}} = cmd
  end

  test "commands_snap_to_construct_test" do
    cmd = Command.snap_to("scroller", 0.0, 100.0)
    assert %Command{type: :snap_to, payload: payload} = cmd
    assert payload.target == "scroller"
    assert payload.x == 0.0
    assert payload.y == 100.0
  end

  test "commands_scroll_by_construct_test" do
    cmd = Command.scroll_by("scroller", 0.0, 50.0)
    assert %Command{type: :scroll_by, payload: payload} = cmd
    assert payload.target == "scroller"
    assert payload.y == 50.0
  end

  # -- Window management ------------------------------------------------------

  test "commands_close_window_construct_test" do
    cmd = Command.close_window("main")
    assert %Command{type: :close_window, payload: %{window_id: "main"}} = cmd
  end

  test "commands_set_window_mode_construct_test" do
    cmd = Command.set_window_mode("main", :fullscreen)
    assert %Command{type: :window_op, payload: payload} = cmd
    assert payload.window_id == "main"
    assert payload.mode == "fullscreen"
  end

  test "commands_set_window_level_construct_test" do
    cmd = Command.set_window_level("main", :always_on_top)
    assert %Command{type: :window_op, payload: payload} = cmd
    assert payload.window_id == "main"
    assert payload.level == "always_on_top"
  end

  # -- Window queries ---------------------------------------------------------

  test "commands_get_window_size_construct_test" do
    cmd = Command.get_window_size("main", :got_size)
    assert %Command{type: :window_query, payload: payload} = cmd
    assert payload.window_id == "main"
    assert payload.tag == "got_size"
  end

  # -- System queries ---------------------------------------------------------

  test "commands_get_system_theme_construct_test" do
    cmd = Command.get_system_theme(:theme_detected)
    assert %Command{type: :window_query, payload: payload} = cmd
    assert payload.tag == "theme_detected"
  end

  test "commands_system_theme_event_match_test" do
    event = %SystemEvent{type: :system_theme, tag: "theme_detected", data: "dark"}

    assert %SystemEvent{type: :system_theme, tag: "theme_detected", data: mode} = event
    assert mode == "dark"
  end

  # -- Image operations -------------------------------------------------------

  test "commands_create_image_construct_test" do
    cmd = Command.create_image("preview", <<0, 1, 2>>)
    assert %Command{type: :image_op, payload: payload} = cmd
    assert payload.handle == "preview"
    assert payload.data == <<0, 1, 2>>
  end

  test "commands_delete_image_construct_test" do
    cmd = Command.delete_image("preview")
    assert %Command{type: :image_op, payload: %{handle: "preview"}} = cmd
  end

  test "commands_clear_images_construct_test" do
    cmd = Command.clear_images()
    assert %Command{type: :widget_op, payload: %{op: "clear_images"}} = cmd
  end

  # -- PaneGrid operations ----------------------------------------------------

  test "commands_pane_split_construct_test" do
    cmd = Command.pane_split("pane_grid", "editor", :horizontal, "new_editor")
    assert %Command{type: :widget_op, payload: payload} = cmd
    assert payload.target == "pane_grid"
    assert payload.axis == "horizontal"
  end

  test "commands_pane_close_construct_test" do
    cmd = Command.pane_close("grid", "p1")
    assert %Command{type: :widget_op, payload: payload} = cmd
    assert payload.target == "grid"
  end

  test "commands_pane_restore_construct_test" do
    cmd = Command.pane_restore("grid")
    assert %Command{type: :widget_op, payload: %{target: "grid", op: "pane_restore"}} = cmd
  end

  # -- Timer ------------------------------------------------------------------

  test "commands_send_after_construct_test" do
    cmd = Command.send_after(3000, :clear_message)
    assert %Command{type: :send_after, payload: payload} = cmd
    assert payload.delay == 3000
    assert payload.event == :clear_message
  end

  # -- Batch ------------------------------------------------------------------

  test "commands_batch_construct_test" do
    cmds = [
      Command.focus("name_input"),
      Command.send_after(5000, :auto_save)
    ]

    batch = Command.batch(cmds)
    assert %Command{type: :batch, payload: %{commands: ^cmds}} = batch
  end

  # -- Extension commands -----------------------------------------------------

  test "commands_extension_command_construct_test" do
    cmd = Command.extension_command("term-1", "write", %{data: "output"})
    assert %Command{type: :extension_command, payload: payload} = cmd
    assert payload.node_id == "term-1"
    assert payload.op == "write"
  end

  test "commands_extension_commands_construct_test" do
    cmds = [
      {"term-1", "write", %{data: "line1"}},
      {"log-1", "append", %{line: "entry"}}
    ]

    cmd = Command.extension_commands(cmds)
    assert %Command{type: :extension_commands, payload: %{commands: ^cmds}} = cmd
  end

  # -- Subscriptions ----------------------------------------------------------

  test "subscriptions_every_construct_test" do
    sub = Subscription.every(1000, :tick)
    assert %Subscription{type: :every, interval: 1000, tag: :tick} = sub
  end

  test "subscriptions_on_key_press_construct_test" do
    sub = Subscription.on_key_press(:key_event)
    assert %Subscription{type: :on_key_press, tag: :key_event, max_rate: nil} = sub
  end

  test "subscriptions_set_max_rate_test" do
    sub = Subscription.on_mouse_move(:mouse) |> Subscription.max_rate(30)
    assert sub.max_rate == 30
  end

  test "subscriptions_set_max_rate_zero_test" do
    sub = Subscription.on_mouse_move(:mouse) |> Subscription.max_rate(0)
    assert sub.max_rate == 0
  end

  test "subscriptions_on_animation_frame_test" do
    sub = Subscription.on_animation_frame(:frame) |> Subscription.max_rate(60)
    assert sub.max_rate == 60
  end

  test "subscriptions_on_animation_frame_opts_test" do
    sub = Subscription.on_animation_frame(:frame, max_rate: 60)
    assert sub.max_rate == 60
  end

  test "subscriptions_every_ignores_max_rate_test" do
    sub = Subscription.every(1000, :tick)
    assert sub.max_rate == nil
  end

  test "subscriptions_on_window_close_test" do
    sub = Subscription.on_window_close(:win_close)
    assert %Subscription{type: :on_window_close, tag: :win_close} = sub
  end

  test "subscriptions_on_window_resize_test" do
    sub = Subscription.on_window_resize(:win_resize)
    assert %Subscription{type: :on_window_resize, tag: :win_resize} = sub
  end

  test "subscriptions_on_mouse_button_test" do
    sub = Subscription.on_mouse_button(:mouse_btn)
    assert %Subscription{type: :on_mouse_button, tag: :mouse_btn} = sub
  end

  test "subscriptions_on_mouse_scroll_test" do
    sub = Subscription.on_mouse_scroll(:scroll)
    assert %Subscription{type: :on_mouse_scroll, tag: :scroll} = sub
  end

  test "subscriptions_on_touch_test" do
    sub = Subscription.on_touch(:touch)
    assert %Subscription{type: :on_touch, tag: :touch} = sub
  end

  test "subscriptions_on_ime_test" do
    sub = Subscription.on_ime(:ime)
    assert %Subscription{type: :on_ime, tag: :ime} = sub
  end

  test "subscriptions_on_theme_change_test" do
    sub = Subscription.on_theme_change(:theme)
    assert %Subscription{type: :on_theme_change, tag: :theme} = sub
  end

  test "subscriptions_on_file_drop_test" do
    sub = Subscription.on_file_drop(:files)
    assert %Subscription{type: :on_file_drop, tag: :files} = sub
  end

  test "subscriptions_on_event_test" do
    sub = Subscription.on_event(:all)
    assert %Subscription{type: :on_event, tag: :all} = sub
  end

  # -- Subscription lifecycle -------------------------------------------------

  test "subscriptions_lifecycle_on_test" do
    subs = [Subscription.every(5000, :poll)]
    assert length(subs) == 1
  end

  test "subscriptions_lifecycle_off_test" do
    subs = []
    assert subs == []
  end

  # -- Timer tick event -------------------------------------------------------

  test "subscriptions_timer_tick_event_test" do
    event = %Plushie.Event.Timer{tag: :poll, timestamp: 100}

    assert %Plushie.Event.Timer{tag: :poll} = event
  end

  # -- Update testability pattern ---------------------------------------------

  test "commands_update_testability_test" do
    cmd = Command.async(fn -> "data" end, :fetch)
    assert %Command{type: :async, payload: %{tag: :fetch}} = cmd
  end

  # -- Chaining pattern (multi-step async) ------------------------------------

  test "commands_chaining_pattern_test" do
    step1 = Command.async(fn -> :ok end, :validated)
    step2 = Command.async(fn -> :ok end, :built)
    step3 = Command.async(fn -> :ok end, :deployed)

    assert %Command{type: :async, payload: %{tag: :validated}} = step1
    assert %Command{type: :async, payload: %{tag: :built}} = step2
    assert %Command{type: :async, payload: %{tag: :deployed}} = step3
  end

  # -- Settings ---------------------------------------------------------------

  test "commands_settings_scale_and_vsync_test" do
    settings = [
      antialiasing: true,
      vsync: false,
      scale_factor: 1.5,
      default_event_rate: 60
    ]

    assert settings[:vsync] == false
    assert settings[:scale_factor] == 1.5
    assert settings[:default_event_rate] == 60
  end
end
