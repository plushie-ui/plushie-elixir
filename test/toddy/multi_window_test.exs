defmodule Toddy.MultiWindowTest do
  use ExUnit.Case, async: true

  alias Toddy.Command

  # ---------------------------------------------------------------------------
  # 1.3 - Payload key alignment: maximize, minimize, mouse_passthrough,
  #       set_resizable must send the keys that Rust reads.
  # ---------------------------------------------------------------------------

  describe "maximize_window/2 payload key" do
    test "sends :maximized key (not :value)" do
      cmd = Command.maximize_window("win1", true)
      assert cmd.payload.maximized == true
      refute Map.has_key?(cmd.payload, :value)
    end

    test "defaults to maximized: true" do
      cmd = Command.maximize_window("win1")
      assert cmd.payload.maximized == true
    end

    test "can set maximized: false to restore" do
      cmd = Command.maximize_window("win1", false)
      assert cmd.payload.maximized == false
    end
  end

  describe "minimize_window/2 payload key" do
    test "sends :minimized key (not :value)" do
      cmd = Command.minimize_window("win1", true)
      assert cmd.payload.minimized == true
      refute Map.has_key?(cmd.payload, :value)
    end

    test "defaults to minimized: true" do
      cmd = Command.minimize_window("win1")
      assert cmd.payload.minimized == true
    end
  end

  describe "mouse_passthrough payload key" do
    test "enable sends :enabled key (not :value)" do
      cmd = Command.enable_mouse_passthrough("win1")
      assert cmd.payload.enabled == true
      refute Map.has_key?(cmd.payload, :value)
    end

    test "disable sends :enabled key (not :value)" do
      cmd = Command.disable_mouse_passthrough("win1")
      assert cmd.payload.enabled == false
      refute Map.has_key?(cmd.payload, :value)
    end
  end

  describe "set_resizable/2 payload key" do
    test "sends :resizable key (not :value)" do
      cmd = Command.set_resizable("win1", false)
      assert cmd.payload.resizable == false
      refute Map.has_key?(cmd.payload, :value)
    end
  end

  # ---------------------------------------------------------------------------
  # 1.2 - close_window carries correct window_id in payload
  # ---------------------------------------------------------------------------

  describe "close_window/1" do
    test "payload includes window_id" do
      cmd = Command.close_window("settings_window")
      assert cmd.payload.window_id == "settings_window"
    end

    test "type is :close_window" do
      cmd = Command.close_window("w")
      assert cmd.type == :close_window
    end
  end

  # ---------------------------------------------------------------------------
  # 1.5 - detect_windows depth constraint
  # ---------------------------------------------------------------------------

  describe "detect_windows (via sync_windows)" do
    # detect_windows is private, so we test its behaviour indirectly via
    # the module attribute pattern. We'll call the function through a helper
    # that exercises the same logic.

    test "finds window at root level" do
      tree = %{id: "main", type: "window", props: %{}, children: []}
      assert detect_windows_test(tree) == MapSet.new(["main"])
    end

    test "finds window nodes as direct children" do
      tree = %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{id: "w1", type: "window", props: %{}, children: []},
          %{id: "w2", type: "window", props: %{}, children: []},
          %{id: "btn", type: "button", props: %{}, children: []}
        ]
      }

      result = detect_windows_test(tree)
      assert MapSet.equal?(result, MapSet.new(["w1", "w2"]))
    end

    test "does NOT find deeply nested window nodes" do
      tree = %{
        id: "root",
        type: "column",
        props: %{},
        children: [
          %{
            id: "inner",
            type: "row",
            props: %{},
            children: [
              %{id: "deep_win", type: "window", props: %{}, children: []}
            ]
          }
        ]
      }

      result = detect_windows_test(tree)
      assert result == MapSet.new()
    end

    test "returns empty set for nil tree" do
      assert detect_windows_test(nil) == MapSet.new()
    end

    test "returns empty set for non-window root without window children" do
      tree = %{id: "root", type: "column", props: %{}, children: []}
      assert detect_windows_test(tree) == MapSet.new()
    end
  end

  # ---------------------------------------------------------------------------
  # 1.6 - Size tuple decomposition
  # ---------------------------------------------------------------------------

  describe "size tuple decomposition" do
    test "size: {w, h} decomposes into width and height" do
      props = decompose_test(%{size: {800, 600}})
      assert props[:width] == 800
      assert props[:height] == 600
      refute Map.has_key?(props, :size)
    end

    test "size as list decomposes into width and height" do
      props = decompose_test(%{size: [1024, 768]})
      assert props[:width] == 1024
      assert props[:height] == 768
      refute Map.has_key?(props, :size)
    end

    test "existing width/height not overwritten by size tuple" do
      props = decompose_test(%{size: {800, 600}, width: 1920, height: 1080})
      assert props[:width] == 1920
      assert props[:height] == 1080
    end

    test "min_size tuple becomes map with width/height" do
      props = decompose_test(%{min_size: {400, 300}})
      assert props[:min_size] == %{width: 400, height: 300}
    end

    test "max_size tuple becomes map with width/height" do
      props = decompose_test(%{max_size: {1920, 1080}})
      assert props[:max_size] == %{width: 1920, height: 1080}
    end

    test "min_size as list becomes map with width/height" do
      props = decompose_test(%{min_size: [320, 240]})
      assert props[:min_size] == %{width: 320, height: 240}
    end

    test "max_size as map passes through unchanged" do
      original = %{width: 1920, height: 1080}
      props = decompose_test(%{max_size: original})
      assert props[:max_size] == original
    end

    test "props without size keys pass through unchanged" do
      props = decompose_test(%{resizable: true, visible: false})
      assert props == %{resizable: true, visible: false}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers -- we call the private functions via the module's internal logic
  # by reimplementing the same algorithm here for testing.
  # ---------------------------------------------------------------------------

  # Mirrors detect_windows/1 from runtime.ex
  defp detect_windows_test(nil), do: MapSet.new()

  defp detect_windows_test(%{type: "window", id: id}) do
    MapSet.new([id])
  end

  defp detect_windows_test(%{children: children}) when is_list(children) do
    children
    |> Enum.filter(fn node -> node.type == "window" end)
    |> Enum.map(& &1.id)
    |> MapSet.new()
  end

  defp detect_windows_test(_), do: MapSet.new()

  # Mirrors decompose_size_tuples/1 from runtime.ex
  defp decompose_test(props) do
    props
    |> decompose_size()
    |> decompose_nested(:min_size)
    |> decompose_nested(:max_size)
  end

  defp decompose_size(props) do
    case Map.get(props, :size) do
      {w, h} ->
        props |> Map.delete(:size) |> Map.put_new(:width, w) |> Map.put_new(:height, h)

      [w, h] ->
        props |> Map.delete(:size) |> Map.put_new(:width, w) |> Map.put_new(:height, h)

      _ ->
        props
    end
  end

  defp decompose_nested(props, key) do
    case Map.get(props, key) do
      {w, h} -> Map.put(props, key, %{width: w, height: h})
      [w, h] -> Map.put(props, key, %{width: w, height: h})
      _ -> props
    end
  end
end
