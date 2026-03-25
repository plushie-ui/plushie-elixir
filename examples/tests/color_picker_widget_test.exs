defmodule Examples.ColorPickerWidgetTest do
  @moduledoc """
  Integration tests for the ColorPickerWidget canvas_widget.

  Tests the widget through the real renderer binary using the
  WidgetCase test harness. Keyboard tests work in all backends
  (mock/headless/windowed). Mouse coordinate tests require
  headless or windowed backends for accurate layout.
  """

  use Plushie.Test.WidgetCase, widget: ColorPickerWidget

  setup do
    init_widget("picker")
  end

  # -- Keyboard: hue cursor ----------------------------------------------------

  test "Tab to hue cursor then ArrowRight adjusts hue" do
    press("tab")
    press("tab")
    press("right")
    assert last_event().type == :change
    assert_in_delta model().hue, 1.0, 0.5
  end

  test "Shift+ArrowRight gives coarse hue step" do
    press("tab")
    press("tab")
    press("shift+right")
    assert_in_delta model().hue, 15.0, 0.5
  end

  test "Home and End set hue extremes" do
    press("tab")
    press("tab")
    press("end")
    assert model().hue == 359.0
    press("home")
    assert model().hue == 0.0
  end

  test "PageUp increments hue by coarse step" do
    press("tab")
    press("tab")
    press("pageup")
    assert_in_delta model().hue, 15.0, 0.5
  end

  # -- Keyboard: SV cursor -----------------------------------------------------

  test "Tab to SV cursor then ArrowLeft decreases saturation" do
    press("tab")
    press("tab")
    press("tab")
    press("left")
    assert_in_delta model().saturation, 0.99, 0.005
  end

  test "ArrowDown on SV cursor decreases value" do
    press("tab")
    press("tab")
    press("tab")
    press("down")
    assert_in_delta model().value, 0.99, 0.005
  end

  test "Shift+Home on SV cursor sets saturation to 0" do
    press("tab")
    press("tab")
    press("tab")
    press("shift+home")
    assert model().saturation == 0.0
  end

  test "End on SV cursor sets value to 0" do
    press("tab")
    press("tab")
    press("tab")
    press("end")
    assert model().value == 0.0
  end

  # -- No event for unrecognized keys ------------------------------------------

  test "pressing an unrecognized key emits nothing" do
    press("tab")
    press("tab")
    press("a")
    assert last_event() == nil
  end

  # -- Mouse: hue ring ---------------------------------------------------------

  test "press on ring at right side sets hue near 90" do
    canvas_press("#picker", 370.0, 200.0)
    assert last_event().type == :change
    assert_in_delta model().hue, 90.0, 2.0
  end

  test "press on ring at bottom sets hue near 180" do
    canvas_press("#picker", 200.0, 370.0)
    assert_in_delta model().hue, 180.0, 2.0
  end

  test "press on ring at left sets hue near 270" do
    canvas_press("#picker", 30.0, 200.0)
    assert_in_delta model().hue, 270.0, 2.0
  end

  # -- Mouse: SV square --------------------------------------------------------

  test "press at center of square sets s=0.5, v=0.5" do
    canvas_press("#picker", 200.0, 200.0)
    assert_in_delta model().saturation, 0.5, 0.01
    assert_in_delta model().value, 0.5, 0.01
  end

  test "press at top-left of square sets s=0, v=1" do
    canvas_press("#picker", 100.0, 100.0)
    assert_in_delta model().saturation, 0.0, 0.01
    assert_in_delta model().value, 1.0, 0.01
  end

  # -- Mouse: outside ----------------------------------------------------------

  test "press outside ring and square emits no event" do
    canvas_press("#picker", 5.0, 5.0)
    assert last_event() == nil
  end
end
