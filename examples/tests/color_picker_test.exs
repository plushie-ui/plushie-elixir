defmodule Examples.ColorPickerTest do
  @moduledoc "Integration tests for the ColorPicker example."

  use Plushie.Test.Case, app: ColorPicker

  # -- Initial render ----------------------------------------------------------

  test "starts with pure red" do
    assert_text("#hex_display", "#ff0000")
    assert_text("#hsv_display", "H: 0  S: 100%  V: 100%")
  end

  test "canvas and swatch exist" do
    assert_exists("#picker")
    assert_exists("#swatch")
  end

  # -- A11y --------------------------------------------------------------------

  test "swatch announces the selected color" do
    assert_a11y("#swatch", %{role: "image", label: "Selected color: #ff0000"})
  end

  test "hex and hsv displays are live regions" do
    assert_a11y("#hex_display", %{live: "polite"})
    assert_a11y("#hsv_display", %{live: "polite"})
  end

  # -- Keyboard: hue cursor ----------------------------------------------------

  # Skipped: keyboard focus does not reach the canvas hue cursor in mock mode.
  @tag :skip
  test "arrow right increases hue" do
    press("Tab")
    press("Tab")
    press("ArrowRight")
    assert model().hue == 1.0
  end

  # Skipped: see "arrow right increases hue".
  @tag :skip
  test "shift+arrow gives coarse hue step" do
    press("Tab")
    press("Tab")
    press("Shift+ArrowRight")
    assert model().hue == 15.0
  end

  # Skipped: see "arrow right increases hue".
  @tag :skip
  test "home and end set hue extremes" do
    press("Tab")
    press("Tab")
    press("End")
    assert model().hue == 359.0
    press("Home")
    assert model().hue == 0.0
  end

  # -- Keyboard: SV cursor -----------------------------------------------------

  # Skipped: see "arrow right increases hue".
  @tag :skip
  test "arrow keys adjust saturation and value on SV cursor" do
    press("Tab")
    press("Tab")
    press("Tab")
    press("ArrowLeft")
    assert_in_delta model().saturation, 0.99, 0.001
    press("ArrowDown")
    assert_in_delta model().value, 0.99, 0.001
  end
end
