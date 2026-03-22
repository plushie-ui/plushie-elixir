defmodule Examples.ColorPickerTest do
  @moduledoc "Integration tests for the ColorPicker example using the test DSL."

  use Plushie.Test.Case, app: ColorPicker

  test "starts with default HSV values" do
    m = model()
    assert m.hue == 0.0
    assert m.saturation == 1.0
    assert m.value == 1.0
    assert m.drag == :none
  end

  test "canvas widget exists" do
    assert_exists("#picker")
  end

  test "hex display shows initial red" do
    assert_text("#hex_display", "#ff0000")
  end

  test "hsv display shows initial values" do
    assert_text("#hsv_display", "H: 0  S: 100%  V: 100%")
  end

  test "swatch container exists" do
    assert_exists("#swatch")
  end
end
