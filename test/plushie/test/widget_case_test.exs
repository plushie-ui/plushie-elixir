defmodule Plushie.Test.WidgetCaseTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.WidgetEvent
  alias Plushie.Test.WidgetCase.HarnessApp

  test "harness preserves unknown string event keys without atomizing them" do
    model =
      HarnessApp.init(
        widget_module: Plushie.Widget.Text,
        widget_id: "subject",
        widget_opts: ["text"]
      )

    event = %WidgetEvent{
      type: :status,
      id: "subject",
      value: %{"events" => "known", "not_existing_widget_case_key" => "dynamic"}
    }

    updated = HarnessApp.update(model, event)

    assert updated.last_value.events == "known"
    assert updated.last_value["not_existing_widget_case_key"] == "dynamic"
  end
end
