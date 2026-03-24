defmodule Examples.ColorPickerTest do
  @moduledoc """
  Integration tests for the ColorPicker example.

  Canvas and a11y tests use the test DSL. Keyboard adjustment tests call
  `ColorPicker.update/2` directly to document the intended keyboard
  behaviour and catch regressions in the update logic.
  """

  use Plushie.Test.Case, app: ColorPicker

  # -- Initial render ----------------------------------------------------------

  test "starts with pure red at full saturation and value" do
    assert_text("#hex_display", "#ff0000")
    assert_text("#hsv_display", "H: 0  S: 100%  V: 100%")
  end

  test "canvas exists" do
    assert_exists("#picker")
  end

  test "swatch exists" do
    assert_exists("#swatch")
  end

  # -- A11y annotations --------------------------------------------------------

  test "swatch announces the selected color" do
    assert_a11y("#swatch", %{role: "image", label: "Selected color: #ff0000"})
  end

  test "hex and hsv displays are live regions" do
    assert_a11y("#hex_display", %{live: "polite"})
    assert_a11y("#hsv_display", %{live: "polite"})
  end

  # -- Keyboard: update/2 unit tests -------------------------------------------

  describe "hue cursor keyboard" do
    test "arrow right/left adjusts hue by 1 degree" do
      m = focus_hue(model())
      assert press_key(m, :arrow_right).hue == 1.0
      assert_in_delta press_key(m, :arrow_left).hue, 359.0, 0.01
    end

    test "shift+arrow adjusts hue by 15 degrees" do
      m = focus_hue(model())
      assert press_key(m, :arrow_right, shift: true).hue == 15.0
    end

    test "hue wraps around at boundaries" do
      assert_in_delta focus_hue(%{model() | hue: 359.0}) |> press_key(:arrow_right) |> Map.get(:hue), 0.0, 0.01
      assert_in_delta focus_hue(model()) |> press_key(:arrow_left) |> Map.get(:hue), 359.0, 0.01
    end

    test "page up/down adjusts hue by 15 degrees" do
      m = focus_hue(model())
      assert press_key(m, :page_up).hue == 15.0
      assert_in_delta focus_hue(%{model() | hue: 30.0}) |> press_key(:page_down) |> Map.get(:hue), 15.0, 0.01
    end

    test "home resets hue to 0, end sets to 359" do
      m = focus_hue(%{model() | hue: 180.0})
      assert press_key(m, :home).hue == 0.0
      assert press_key(m, :end).hue == 359.0
    end
  end

  describe "SV cursor keyboard" do
    test "arrow right/left adjusts saturation" do
      m = focus_sv(%{model() | saturation: 0.5})
      assert_in_delta press_key(m, :arrow_right).saturation, 0.51, 0.001
      assert_in_delta press_key(m, :arrow_left).saturation, 0.49, 0.001
    end

    test "arrow up/down adjusts value" do
      m = focus_sv(%{model() | value: 0.5})
      assert_in_delta press_key(m, :arrow_up).value, 0.51, 0.001
      assert_in_delta press_key(m, :arrow_down).value, 0.49, 0.001
    end

    test "shift+arrow gives coarse step" do
      m = focus_sv(%{model() | saturation: 0.5, value: 0.5})
      assert_in_delta press_key(m, :arrow_right, shift: true).saturation, 0.6, 0.001
      assert_in_delta press_key(m, :arrow_up, shift: true).value, 0.6, 0.001
    end

    test "saturation and value clamp to 0..1" do
      m_low = focus_sv(%{model() | saturation: 0.0, value: 0.0})
      assert press_key(m_low, :arrow_left).saturation == 0.0
      assert press_key(m_low, :arrow_down).value == 0.0

      m_high = focus_sv(%{model() | saturation: 1.0, value: 1.0})
      assert press_key(m_high, :arrow_right).saturation == 1.0
      assert press_key(m_high, :arrow_up).value == 1.0
    end

    test "page up/down adjusts value, shift+page adjusts saturation" do
      m = focus_sv(%{model() | saturation: 0.5, value: 0.5})
      assert_in_delta press_key(m, :page_up).value, 0.6, 0.001
      assert_in_delta press_key(m, :page_down).value, 0.4, 0.001
      assert_in_delta press_key(m, :page_up, shift: true).saturation, 0.6, 0.001
      assert_in_delta press_key(m, :page_down, shift: true).saturation, 0.4, 0.001
    end

    test "home/end controls value, shift+home/end controls saturation" do
      m = focus_sv(%{model() | saturation: 0.5, value: 0.5})
      assert press_key(m, :home).value == 1.0
      assert press_key(m, :end).value == 0.0
      assert press_key(m, :home, shift: true).saturation == 0.0
      assert press_key(m, :end, shift: true).saturation == 1.0
    end
  end

  describe "keyboard no-ops" do
    test "keys ignored when no cursor is focused" do
      m = press_key(model(), :arrow_right)
      assert m.hue == 0.0
    end

    test "keys ignored for unknown focus target" do
      m = press_key(%{model() | focus: "unknown"}, :arrow_right)
      assert m.hue == 0.0
    end

    test "captured keys ignored even with focus" do
      m = focus_hue(model())
      event = make_key(:arrow_right, captured: true)
      {m, _} = dispatch(m, event)
      assert m.hue == 0.0
    end
  end

  # -- Helpers -----------------------------------------------------------------
  # These bypass the test DSL to call update/2 directly. Named to read
  # naturally in test bodies rather than exposing event struct details.

  defp dispatch(m, event) do
    case ColorPicker.update(m, event) do
      {model, commands} when is_list(commands) -> {model, commands}
      {model, %Plushie.Command{} = cmd} -> {model, [cmd]}
      model -> {model, []}
    end
  end

  defp focus_hue(m), do: focus(m, "hue-cursor")
  defp focus_sv(m), do: focus(m, "sv-cursor")

  defp focus(m, cursor_id) do
    {m, _} =
      dispatch(m, %Plushie.Event.Widget{
        type: :canvas_element_focused,
        id: cursor_id,
        scope: ["picker"],
        data: nil
      })

    m
  end

  defp press_key(m, key, opts \\ []) do
    {m, _} = dispatch(m, make_key(key, opts))
    m
  end

  defp make_key(key, opts) do
    %Plushie.Event.Key{
      type: :press,
      key: key,
      modified_key: nil,
      physical_key: nil,
      location: :standard,
      modifiers: %Plushie.KeyModifiers{
        ctrl: opts[:ctrl] || false,
        shift: opts[:shift] || false,
        alt: opts[:alt] || false,
        logo: opts[:logo] || false,
        command: opts[:command] || false
      },
      text: nil,
      repeat: false,
      captured: opts[:captured] || false
    }
  end
end
