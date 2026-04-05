defmodule Plushie.DevOverlayTest do
  use ExUnit.Case, async: true

  @moduletag capture_log: true

  alias Plushie.Dev.RebuildingOverlay

  # -- Test app ---------------------------------------------------------------

  defmodule OverlayTestApp do
    use Plushie.App

    def init(_opts), do: %{value: 0}
    def update(model, _event), do: model

    def view(_model) do
      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{id: "content", type: "text", props: %{content: "hello"}, children: []}
        ]
      }
    end
  end

  # -- Tests ------------------------------------------------------------------

  describe "dev overlay injection" do
    test "sending :building overlay injects overlay nodes into tree" do
      session = Plushie.Test.Session.start(OverlayTestApp)
      runtime = Plushie.Test.Session.runtime(session)

      overlay = %RebuildingOverlay{status: :building, detail: "", expanded: false}
      send(runtime, {:dev_overlay, overlay})
      Plushie.Runtime.sync(runtime)

      tree = Plushie.Test.Session.tree(session)
      assert find_by_id(tree, "__plushie_dev__/bar") != nil
      assert find_by_id(tree, "__plushie_dev__/status") != nil

      Plushie.Test.Session.stop(session)
    end

    test "overlay status text matches status" do
      session = Plushie.Test.Session.start(OverlayTestApp)
      runtime = Plushie.Test.Session.runtime(session)

      overlay = %RebuildingOverlay{status: :failed, detail: "compile error", expanded: false}
      send(runtime, {:dev_overlay, overlay})
      Plushie.Runtime.sync(runtime)

      tree = Plushie.Test.Session.tree(session)
      status_node = find_by_id(tree, "__plushie_dev__/status")
      assert status_node != nil
      assert status_node.props.content == "Rebuild failed."

      Plushie.Test.Session.stop(session)
    end

    test "expanded overlay includes drawer" do
      session = Plushie.Test.Session.start(OverlayTestApp)
      runtime = Plushie.Test.Session.runtime(session)

      overlay = %RebuildingOverlay{status: :building, detail: "compiling...", expanded: true}
      send(runtime, {:dev_overlay, overlay})
      Plushie.Runtime.sync(runtime)

      tree = Plushie.Test.Session.tree(session)
      assert find_by_id(tree, "__plushie_dev__/drawer") != nil
      output_node = find_by_id(tree, "__plushie_dev__/output")
      assert output_node != nil
      assert output_node.props.content == "compiling..."

      Plushie.Test.Session.stop(session)
    end

    test "collapsed overlay does not include drawer" do
      session = Plushie.Test.Session.start(OverlayTestApp)
      runtime = Plushie.Test.Session.runtime(session)

      overlay = %RebuildingOverlay{status: :building, detail: "", expanded: false}
      send(runtime, {:dev_overlay, overlay})
      Plushie.Runtime.sync(runtime)

      tree = Plushie.Test.Session.tree(session)
      assert find_by_id(tree, "__plushie_dev__/drawer") == nil

      Plushie.Test.Session.stop(session)
    end

    test "failed overlay includes dismiss button" do
      session = Plushie.Test.Session.start(OverlayTestApp)
      runtime = Plushie.Test.Session.runtime(session)

      overlay = %RebuildingOverlay{status: :failed, detail: "error", expanded: false}
      send(runtime, {:dev_overlay, overlay})
      Plushie.Runtime.sync(runtime)

      tree = Plushie.Test.Session.tree(session)
      assert find_by_id(tree, "__plushie_dev__/dismiss") != nil

      Plushie.Test.Session.stop(session)
    end

    test "building overlay does not include dismiss button" do
      session = Plushie.Test.Session.start(OverlayTestApp)
      runtime = Plushie.Test.Session.runtime(session)

      overlay = %RebuildingOverlay{status: :building, detail: "", expanded: false}
      send(runtime, {:dev_overlay, overlay})
      Plushie.Runtime.sync(runtime)

      tree = Plushie.Test.Session.tree(session)
      assert find_by_id(tree, "__plushie_dev__/dismiss") == nil

      Plushie.Test.Session.stop(session)
    end

    test "succeeded overlay auto-dismisses after timeout" do
      session = Plushie.Test.Session.start(OverlayTestApp)
      runtime = Plushie.Test.Session.runtime(session)

      overlay = %RebuildingOverlay{status: :succeeded, detail: "", expanded: false}
      send(runtime, {:dev_overlay, overlay})
      Plushie.Runtime.sync(runtime)

      # Overlay should be present initially
      tree = Plushie.Test.Session.tree(session)
      assert find_by_id(tree, "__plushie_dev__/bar") != nil

      # Wait for auto-dismiss
      dismiss_ms = RebuildingOverlay.dismiss_ms()
      Process.sleep(dismiss_ms + 100)
      Plushie.Runtime.sync(runtime)

      tree = Plushie.Test.Session.tree(session)
      assert find_by_id(tree, "__plushie_dev__/bar") == nil

      Plushie.Test.Session.stop(session)
    end
  end

  # -- Helpers ----------------------------------------------------------------

  defp find_by_id(nil, _id), do: nil

  defp find_by_id(%{id: id} = node, target_id) when id == target_id, do: node

  defp find_by_id(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, fn child -> find_by_id(child, target_id) end)
  end

  defp find_by_id(_node, _target_id), do: nil
end
