defmodule Plushie.Test.CanvasElementClickTest do
  @moduledoc """
  Tests that click("#canvas_id/element_id") dispatches a canvas element
  click event through the mock renderer.
  """

  use ExUnit.Case, async: true

  alias Plushie.Event.WidgetEvent
  alias Plushie.Test.Backend.Runtime

  @moduletag backend: :runtime
  @moduletag capture_log: true

  defmodule CanvasClickApp do
    @moduledoc false
    use Plushie.App

    def init(_opts), do: %{clicked: nil}

    def update(model, %WidgetEvent{type: :click, id: "save-btn", scope: ["toolbar" | _]} = _event) do
      %{model | clicked: :save}
    end

    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      window "main" do
        canvas "toolbar", width: 200, height: 50 do
          layer "buttons" do
            group "save-btn", on_click: true do
              rect(0, 0, 80, 40, fill: "#ccc")
            end
          end
        end
      end
    end
  end

  setup do
    {:ok, pid} = Runtime.start(CanvasClickApp, pool: Plushie.TestPool)
    on_exit(fn -> if Process.alive?(pid), do: Runtime.stop(pid) end)
    {:ok, pid: pid}
  end

  describe "canvas element click via scoped ID" do
    test "dispatches click event with scoped ID", %{pid: pid} do
      Runtime.click(pid, "#toolbar/save-btn")
      assert Runtime.model(pid).clicked == :save
    end
  end
end
