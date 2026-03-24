defmodule Examples.ColorPickerTest do
  @moduledoc "Integration tests for the ColorPicker example using the test DSL."

  use Plushie.Test.Case, app: ColorPicker

  # -- Initial state -----------------------------------------------------------

  test "starts with default HSV values" do
    m = model()
    assert m.hue == 0.0
    assert m.saturation == 1.0
    assert m.value == 1.0
    assert m.drag == :none
    assert m.focus == nil
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

  # -- A11y: canvas labeling ---------------------------------------------------

  test "canvas has accessible label" do
    element = find!("#picker")
    assert element.props[:alt] == "HSV color picker"
  end

  test "canvas has accessible description" do
    element = find!("#picker")
    assert is_binary(element.props[:description])
  end

  test "canvas uses arrow_mode none for keyboard propagation" do
    element = find!("#picker")
    assert element.props[:arrow_mode] == "none"
  end

  # -- A11y: swatch and text displays ------------------------------------------

  test "swatch has image role and color label" do
    assert_a11y("#swatch", %{"role" => "image"})
    swatch_a11y = find!("#swatch") |> Plushie.Test.Element.a11y()
    assert swatch_a11y["label"] =~ "#ff0000"
  end

  test "hex display has live region for screen reader announcements" do
    assert_a11y("#hex_display", %{"live" => "polite"})
  end

  test "hsv display has live region for screen reader announcements" do
    assert_a11y("#hsv_display", %{"live" => "polite"})
  end

  # -- Keyboard: focus tracking ------------------------------------------------
  # NOTE: Raw canvas mouse events (Canvas.press/move/release) are delivered
  # as %Widget{type: :canvas_press} in the mock backend, which doesn't match
  # the %Canvas{type: :press} pattern the app uses. Mouse interaction tests
  # require a headless or windowed backend. Keyboard and a11y are tested here.

  test "focus tracking via canvas_element_focused event" do
    # Directly verify the update/2 focus tracking logic
    focused_event = %Plushie.Event.Widget{
      type: :canvas_element_focused,
      id: "picker",
      scope: [],
      data: %{"element_id" => "hue-cursor"}
    }

    m = model()
    {m, _} = apply_update(m, focused_event)
    assert m.focus == "hue-cursor"
  end

  test "focus clears on canvas_element_blurred event" do
    focused = %Plushie.Event.Widget{
      type: :canvas_element_focused,
      id: "picker",
      scope: [],
      data: %{"element_id" => "hue-cursor"}
    }

    blurred = %Plushie.Event.Widget{
      type: :canvas_element_blurred,
      id: "picker",
      scope: [],
      data: %{"element_id" => "hue-cursor"}
    }

    m = model()
    {m, _} = apply_update(m, focused)
    assert m.focus == "hue-cursor"
    {m, _} = apply_update(m, blurred)
    assert m.focus == nil
  end

  test "focusing a different cursor replaces the previous focus" do
    m = model()
    m = focus_cursor(m, "hue-cursor")
    assert m.focus == "hue-cursor"
    m = focus_cursor(m, "sv-cursor")
    assert m.focus == "sv-cursor"
  end

  # -- Keyboard: hue cursor ----------------------------------------------------

  test "arrow right increases hue when hue cursor is focused" do
    m = focus_cursor(model(), "hue-cursor")
    m = press_key(m, :arrow_right)
    assert m.hue == 1.0
  end

  test "arrow left decreases hue when hue cursor is focused" do
    m = focus_cursor(model(), "hue-cursor")
    m = press_key(m, :arrow_left)
    assert_in_delta m.hue, 359.0, 0.01
  end

  test "shift+arrow gives coarse hue step" do
    m = focus_cursor(model(), "hue-cursor")
    m = press_key(m, :arrow_right, shift: true)
    assert m.hue == 15.0
  end

  test "hue wraps around 360" do
    m = focus_cursor(%{model() | hue: 359.0}, "hue-cursor")
    m = press_key(m, :arrow_right)
    assert_in_delta m.hue, 0.0, 0.01
  end

  test "hue wraps around 0" do
    m = focus_cursor(model(), "hue-cursor")
    m = press_key(m, :arrow_left)
    assert_in_delta m.hue, 359.0, 0.01
  end

  test "page up gives coarse hue increase" do
    m = focus_cursor(model(), "hue-cursor")
    m = press_key(m, :page_up)
    assert m.hue == 15.0
  end

  test "page down gives coarse hue decrease" do
    m = focus_cursor(%{model() | hue: 30.0}, "hue-cursor")
    m = press_key(m, :page_down)
    assert_in_delta m.hue, 15.0, 0.01
  end

  test "home sets hue to 0" do
    m = focus_cursor(%{model() | hue: 180.0}, "hue-cursor")
    m = press_key(m, :home)
    assert m.hue == 0.0
  end

  test "end sets hue to 359" do
    m = focus_cursor(model(), "hue-cursor")
    m = press_key(m, :end)
    assert m.hue == 359.0
  end

  # -- Keyboard: SV cursor -----------------------------------------------------

  test "arrow right increases saturation" do
    m = focus_cursor(%{model() | saturation: 0.5}, "sv-cursor")
    m = press_key(m, :arrow_right)
    assert_in_delta m.saturation, 0.51, 0.001
  end

  test "arrow left decreases saturation" do
    m = focus_cursor(%{model() | saturation: 0.5}, "sv-cursor")
    m = press_key(m, :arrow_left)
    assert_in_delta m.saturation, 0.49, 0.001
  end

  test "arrow up increases value" do
    m = focus_cursor(%{model() | value: 0.5}, "sv-cursor")
    m = press_key(m, :arrow_up)
    assert_in_delta m.value, 0.51, 0.001
  end

  test "arrow down decreases value" do
    m = focus_cursor(%{model() | value: 0.5}, "sv-cursor")
    m = press_key(m, :arrow_down)
    assert_in_delta m.value, 0.49, 0.001
  end

  test "shift+arrow gives coarse saturation step" do
    m = focus_cursor(%{model() | saturation: 0.5}, "sv-cursor")
    m = press_key(m, :arrow_right, shift: true)
    assert_in_delta m.saturation, 0.6, 0.001
  end

  test "saturation clamps at 0" do
    m = focus_cursor(%{model() | saturation: 0.0}, "sv-cursor")
    m = press_key(m, :arrow_left)
    assert m.saturation == 0.0
  end

  test "saturation clamps at 1" do
    m = focus_cursor(%{model() | saturation: 1.0}, "sv-cursor")
    m = press_key(m, :arrow_right)
    assert m.saturation == 1.0
  end

  test "value clamps at 0" do
    m = focus_cursor(%{model() | value: 0.0}, "sv-cursor")
    m = press_key(m, :arrow_down)
    assert m.value == 0.0
  end

  test "value clamps at 1" do
    m = focus_cursor(%{model() | value: 1.0}, "sv-cursor")
    m = press_key(m, :arrow_up)
    assert m.value == 1.0
  end

  # -- Keyboard: SV page up/down and home/end ----------------------------------

  test "page up increases value by coarse step" do
    m = focus_cursor(%{model() | value: 0.5}, "sv-cursor")
    m = press_key(m, :page_up)
    assert_in_delta m.value, 0.6, 0.001
  end

  test "page down decreases value by coarse step" do
    m = focus_cursor(%{model() | value: 0.5}, "sv-cursor")
    m = press_key(m, :page_down)
    assert_in_delta m.value, 0.4, 0.001
  end

  test "shift+page up increases saturation by coarse step" do
    m = focus_cursor(%{model() | saturation: 0.5}, "sv-cursor")
    m = press_key(m, :page_up, shift: true)
    assert_in_delta m.saturation, 0.6, 0.001
  end

  test "shift+page down decreases saturation by coarse step" do
    m = focus_cursor(%{model() | saturation: 0.5}, "sv-cursor")
    m = press_key(m, :page_down, shift: true)
    assert_in_delta m.saturation, 0.4, 0.001
  end

  test "home sets value to max (white)" do
    m = focus_cursor(%{model() | value: 0.3}, "sv-cursor")
    m = press_key(m, :home)
    assert m.value == 1.0
  end

  test "end sets value to min (black)" do
    m = focus_cursor(%{model() | value: 0.8}, "sv-cursor")
    m = press_key(m, :end)
    assert m.value == 0.0
  end

  test "shift+home sets saturation to min" do
    m = focus_cursor(%{model() | saturation: 0.7}, "sv-cursor")
    m = press_key(m, :home, shift: true)
    assert m.saturation == 0.0
  end

  test "shift+end sets saturation to max" do
    m = focus_cursor(%{model() | saturation: 0.3}, "sv-cursor")
    m = press_key(m, :end, shift: true)
    assert m.saturation == 1.0
  end

  # -- Keyboard: no-op when unfocused ------------------------------------------

  test "key events are ignored when no cursor is focused" do
    m = model()
    assert m.focus == nil

    m = press_key(m, :arrow_right)
    assert m.hue == 0.0
    assert m.saturation == 1.0
    assert m.value == 1.0
  end

  test "key events are ignored when an unknown element is focused" do
    m = %{model() | focus: "unknown-element"}
    m = press_key(m, :arrow_right)
    assert m.hue == 0.0
    assert m.saturation == 1.0
    assert m.value == 1.0
  end

  test "captured key events are ignored" do
    m = focus_cursor(model(), "hue-cursor")
    event = make_key(:arrow_right, captured: true)
    {m, _} = apply_update(m, event)
    assert m.hue == 0.0
  end

  # -- Helpers -----------------------------------------------------------------

  defp apply_update(m, event) do
    case ColorPicker.update(m, event) do
      {model, commands} when is_list(commands) -> {model, commands}
      {model, %Plushie.Command{} = cmd} -> {model, [cmd]}
      model -> {model, []}
    end
  end

  defp focus_cursor(m, cursor_id) do
    event = %Plushie.Event.Widget{
      type: :canvas_element_focused,
      id: "picker",
      scope: [],
      data: %{"element_id" => cursor_id}
    }

    {m, _} = apply_update(m, event)
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
        ctrl: Keyword.get(opts, :ctrl, false),
        shift: Keyword.get(opts, :shift, false),
        alt: Keyword.get(opts, :alt, false),
        logo: Keyword.get(opts, :logo, false),
        command: Keyword.get(opts, :command, false)
      },
      text: nil,
      repeat: false,
      captured: Keyword.get(opts, :captured, false)
    }
  end

  defp press_key(m, key, opts \\ []) do
    event = make_key(key, opts)
    {m, _} = apply_update(m, event)
    m
  end
end
