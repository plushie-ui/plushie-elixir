defmodule Plushie.CommandParityTest do
  @moduledoc """
  Tests for all new commands added in the iced parity pass.
  Does not duplicate tests from command_test.exs.
  """
  use ExUnit.Case, async: true

  alias Plushie.Command

  describe "exit/0" do
    test "returns exit command" do
      cmd = Command.exit()
      assert %Command{type: :exit, payload: %{}} = cmd
    end
  end

  describe "snap_to/3" do
    test "snaps scrollable to offset with defaults" do
      cmd = Command.snap_to("scr1")
      assert %Command{type: :snap_to, payload: payload} = cmd
      assert payload.target == "scr1"
      assert payload.x == 0.0
      assert payload.y == 0.0
    end

    test "snaps scrollable to specific offset" do
      cmd = Command.snap_to("scr1", 0.5, 1.0)
      assert cmd.payload.x == 0.5
      assert cmd.payload.y == 1.0
    end
  end

  describe "snap_to_end/1" do
    test "snaps scrollable to end" do
      cmd = Command.snap_to_end("scr1")
      assert %Command{type: :snap_to_end, payload: %{target: "scr1"}} = cmd
    end
  end

  describe "scroll_by/3" do
    test "scrolls by relative offset with defaults" do
      cmd = Command.scroll_by("scr1")
      assert %Command{type: :scroll_by, payload: payload} = cmd
      assert payload.target == "scr1"
      assert payload.x == 0.0
      assert payload.y == 0.0
    end

    test "scrolls by specific offset" do
      cmd = Command.scroll_by("scr1", 10.0, -20.0)
      assert cmd.payload.x == 10.0
      assert cmd.payload.y == -20.0
    end
  end

  describe "move_cursor_to_front/1" do
    test "returns correct command" do
      cmd = Command.move_cursor_to_front("editor1")
      assert %Command{type: :move_cursor_to_front, payload: %{target: "editor1"}} = cmd
    end
  end

  describe "move_cursor_to_end/1" do
    test "returns correct command" do
      cmd = Command.move_cursor_to_end("editor1")
      assert %Command{type: :move_cursor_to_end, payload: %{target: "editor1"}} = cmd
    end
  end

  describe "move_cursor_to/2" do
    test "moves cursor to specific position" do
      cmd = Command.move_cursor_to("editor1", 42)
      assert %Command{type: :move_cursor_to, payload: %{target: "editor1", position: 42}} = cmd
    end
  end

  describe "select_range/3" do
    test "selects a range of text" do
      cmd = Command.select_range("editor1", 5, 15)
      assert %Command{type: :select_range} = cmd
      assert cmd.payload.target == "editor1"
      assert cmd.payload.start == 5
      assert cmd.payload.end == 15
    end
  end

  describe "resize_window/3" do
    test "creates resize window op" do
      cmd = Command.resize_window("main", 1024, 768)
      assert %Command{type: :window_op} = cmd
      assert cmd.payload.op == "resize"
      assert cmd.payload.window_id == "main"
      assert cmd.payload.width == 1024
      assert cmd.payload.height == 768
    end
  end

  describe "move_window/3" do
    test "creates move window op" do
      cmd = Command.move_window("main", 100, 200)
      assert cmd.payload.op == "move"
      assert cmd.payload.x == 100
      assert cmd.payload.y == 200
    end
  end

  describe "maximize_window/2" do
    test "defaults to maximized true" do
      cmd = Command.maximize_window("main")
      assert cmd.payload.op == "maximize"
      assert cmd.payload.maximized == true
    end

    test "can set maximized false to restore" do
      cmd = Command.maximize_window("main", false)
      assert cmd.payload.maximized == false
    end
  end

  describe "minimize_window/2" do
    test "defaults to minimized true" do
      cmd = Command.minimize_window("main")
      assert cmd.payload.op == "minimize"
      assert cmd.payload.minimized == true
    end

    test "can set minimized false to restore" do
      cmd = Command.minimize_window("main", false)
      assert cmd.payload.minimized == false
    end
  end

  describe "set_window_mode/2" do
    test "sets window mode from atom" do
      cmd = Command.set_window_mode("main", :fullscreen)
      assert cmd.payload.op == "set_mode"
      assert cmd.payload.mode == "fullscreen"
    end

    test "sets window mode from string" do
      cmd = Command.set_window_mode("main", "windowed")
      assert cmd.payload.mode == "windowed"
    end
  end

  describe "toggle_maximize/1" do
    test "creates toggle maximize op" do
      cmd = Command.toggle_maximize("main")
      assert cmd.payload.op == "toggle_maximize"
      assert cmd.payload.window_id == "main"
    end
  end

  describe "toggle_decorations/1" do
    test "creates toggle decorations op" do
      cmd = Command.toggle_decorations("main")
      assert cmd.payload.op == "toggle_decorations"
    end
  end

  describe "focus_window/1" do
    test "creates gain focus op" do
      cmd = Command.focus_window("main")
      assert cmd.payload.op == "gain_focus"
    end
  end

  describe "set_window_level/2" do
    test "sets level from atom" do
      cmd = Command.set_window_level("main", :always_on_top)
      assert cmd.payload.op == "set_level"
      assert cmd.payload.level == "always_on_top"
    end
  end

  describe "drag_window/1" do
    test "creates drag op" do
      cmd = Command.drag_window("main")
      assert cmd.payload.op == "drag"
    end
  end

  describe "drag_resize_window/2" do
    test "creates drag resize op with direction" do
      cmd = Command.drag_resize_window("main", :south_east)
      assert cmd.payload.op == "drag_resize"
      assert cmd.payload.direction == "south_east"
    end
  end

  describe "request_user_attention/2" do
    test "defaults to nil urgency" do
      cmd = Command.request_user_attention("main")
      assert cmd.payload.op == "request_attention"
      assert cmd.payload.urgency == nil
    end

    test "accepts urgency level" do
      cmd = Command.request_user_attention("main", :critical)
      assert cmd.payload.urgency == "critical"
    end
  end

  describe "screenshot/2" do
    test "creates screenshot op with tag" do
      cmd = Command.screenshot("main", :captured)
      assert cmd.payload.op == "screenshot"
      assert cmd.payload.tag == "captured"
    end
  end

  describe "set_resizable/2" do
    test "sets resizable flag" do
      cmd = Command.set_resizable("main", false)
      assert cmd.payload.op == "set_resizable"
      assert cmd.payload.resizable == false
    end
  end

  describe "set_min_size/3" do
    test "sets minimum window size" do
      cmd = Command.set_min_size("main", 400, 300)
      assert cmd.payload.op == "set_min_size"
      assert cmd.payload.width == 400
      assert cmd.payload.height == 300
    end
  end

  describe "set_max_size/3" do
    test "sets maximum window size" do
      cmd = Command.set_max_size("main", 1920, 1080)
      assert cmd.payload.op == "set_max_size"
      assert cmd.payload.width == 1920
      assert cmd.payload.height == 1080
    end
  end

  describe "enable_mouse_passthrough/1" do
    test "enables passthrough" do
      cmd = Command.enable_mouse_passthrough("overlay")
      assert cmd.payload.op == "mouse_passthrough"
      assert cmd.payload.enabled == true
    end
  end

  describe "disable_mouse_passthrough/1" do
    test "disables passthrough" do
      cmd = Command.disable_mouse_passthrough("overlay")
      assert cmd.payload.op == "mouse_passthrough"
      assert cmd.payload.enabled == false
    end
  end

  describe "show_system_menu/1" do
    test "creates show system menu op" do
      cmd = Command.show_system_menu("main")
      assert cmd.payload.op == "show_system_menu"
    end
  end

  describe "get_window_size/2" do
    test "creates size query" do
      cmd = Command.get_window_size("main", :size_result)
      assert %Command{type: :window_query} = cmd
      assert cmd.payload.op == "get_size"
      assert cmd.payload.tag == "size_result"
    end
  end

  describe "get_window_position/2" do
    test "creates position query" do
      cmd = Command.get_window_position("main", :pos_result)
      assert cmd.payload.op == "get_position"
      assert cmd.payload.tag == "pos_result"
    end
  end

  describe "is_maximized/2" do
    test "creates maximized query" do
      cmd = Command.is_maximized("main", :max_result)
      assert cmd.payload.op == "is_maximized"
      assert cmd.payload.tag == "max_result"
    end
  end

  describe "is_minimized/2" do
    test "creates minimized query" do
      cmd = Command.is_minimized("main", :min_result)
      assert cmd.payload.op == "is_minimized"
      assert cmd.payload.tag == "min_result"
    end
  end

  describe "struct consistency" do
    test "all new commands are Command structs" do
      commands = [
        Command.exit(),
        Command.snap_to("s"),
        Command.snap_to_end("s"),
        Command.scroll_by("s"),
        Command.move_cursor_to_front("e"),
        Command.move_cursor_to_end("e"),
        Command.move_cursor_to("e", 0),
        Command.select_range("e", 0, 1),
        Command.resize_window("w", 100, 100),
        Command.move_window("w", 0, 0),
        Command.maximize_window("w"),
        Command.minimize_window("w"),
        Command.set_window_mode("w", :windowed),
        Command.toggle_maximize("w"),
        Command.toggle_decorations("w"),
        Command.focus_window("w"),
        Command.set_window_level("w", :normal),
        Command.drag_window("w"),
        Command.drag_resize_window("w", :south),
        Command.request_user_attention("w"),
        Command.screenshot("w", :tag),
        Command.set_resizable("w", true),
        Command.set_min_size("w", 1, 1),
        Command.set_max_size("w", 1, 1),
        Command.enable_mouse_passthrough("w"),
        Command.disable_mouse_passthrough("w"),
        Command.show_system_menu("w"),
        Command.get_window_size("w", :t),
        Command.get_window_position("w", :t),
        Command.is_maximized("w", :t),
        Command.is_minimized("w", :t)
      ]

      for cmd <- commands do
        assert %Command{} = cmd, "Expected Command struct, got: #{inspect(cmd)}"
      end
    end
  end
end
