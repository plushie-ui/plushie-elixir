defmodule ColorPickerTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.Widget

  # ---------------------------------------------------------------------------
  # init/1
  # ---------------------------------------------------------------------------

  describe "init/1" do
    test "returns initial model with red selected" do
      model = ColorPicker.init([])
      assert model.hue == 0.0
      assert model.saturation == 1.0
      assert model.value == 1.0
    end

    test "model has no internal widget state (drag, focus)" do
      model = ColorPicker.init([])
      refute Map.has_key?(model, :drag)
      refute Map.has_key?(model, :focused)
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- change events from ColorPickerWidget
  # ---------------------------------------------------------------------------

  describe "update/2 -- change events" do
    test "updates hue from picker :change event" do
      model = ColorPicker.init([])

      result =
        ColorPicker.update(model, %Widget{
          type: :change,
          id: "picker",
          data: %{"hue" => 120.0, "saturation" => 1.0, "value" => 1.0}
        })

      assert result.hue == 120.0
      assert result.saturation == 1.0
      assert result.value == 1.0
    end

    test "updates all HSV components" do
      model = ColorPicker.init([])

      result =
        ColorPicker.update(model, %Widget{
          type: :change,
          id: "picker",
          data: %{"hue" => 210.0, "saturation" => 0.75, "value" => 0.6}
        })

      assert result.hue == 210.0
      assert result.saturation == 0.75
      assert result.value == 0.6
    end

    test "successive changes accumulate" do
      model =
        ColorPicker.init([])
        |> ColorPicker.update(%Widget{
          type: :change,
          id: "picker",
          data: %{"hue" => 90.0, "saturation" => 0.5, "value" => 0.8}
        })
        |> ColorPicker.update(%Widget{
          type: :change,
          id: "picker",
          data: %{"hue" => 91.0, "saturation" => 0.5, "value" => 0.8}
        })

      assert model.hue == 91.0
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- unknown events
  # ---------------------------------------------------------------------------

  describe "update/2 -- unknown events" do
    test "non-picker events are ignored" do
      model = ColorPicker.init([])
      assert ColorPicker.update(model, %Widget{type: :click, id: "something"}) == model
    end

    test "change from wrong id is ignored" do
      model = ColorPicker.init([])

      assert ColorPicker.update(model, %Widget{
               type: :change,
               id: "not_picker",
               data: %{"hue" => 999.0, "saturation" => 0.0, "value" => 0.0}
             }) == model
    end

    test "bare atom events are ignored" do
      model = ColorPicker.init([])
      assert ColorPicker.update(model, :tick) == model
    end
  end

  # ---------------------------------------------------------------------------
  # view/1 -- tree structure
  # ---------------------------------------------------------------------------

  describe "view/1 -- tree structure" do
    test "returns a window node" do
      tree = ColorPicker.view(ColorPicker.init([]))
      assert tree.type == "window"
      assert tree.id == "color_picker"
    end

    test "picker canvas widget is present" do
      tree = ColorPicker.view(ColorPicker.init([]))
      picker = Plushie.UI.find(tree, "picker")
      assert picker != nil
      assert picker.type == "canvas"
    end

    test "swatch container is present" do
      tree = ColorPicker.view(ColorPicker.init([]))
      swatch = Plushie.UI.find(tree, "swatch")
      assert swatch != nil
      assert swatch.type == "container"
    end
  end

  # ---------------------------------------------------------------------------
  # view/1 -- color display
  # ---------------------------------------------------------------------------

  describe "view/1 -- color display" do
    test "initial model shows red (#ff0000)" do
      tree = ColorPicker.view(ColorPicker.init([]))
      swatch = Plushie.UI.find(tree, "swatch")
      assert swatch.props[:background] == "#ff0000"

      hex_text = Plushie.UI.find(tree, "hex_display")
      assert hex_text.props[:content] == "#ff0000"
    end

    test "pure green at hue=120" do
      model = %{hue: 120.0, saturation: 1.0, value: 1.0}
      tree = ColorPicker.view(model)
      swatch = Plushie.UI.find(tree, "swatch")
      assert swatch.props[:background] == "#00ff00"
    end

    test "pure blue at hue=240" do
      model = %{hue: 240.0, saturation: 1.0, value: 1.0}
      tree = ColorPicker.view(model)
      swatch = Plushie.UI.find(tree, "swatch")
      assert swatch.props[:background] == "#0000ff"
    end

    test "white at s=0, v=1" do
      model = %{hue: 0.0, saturation: 0.0, value: 1.0}
      tree = ColorPicker.view(model)
      swatch = Plushie.UI.find(tree, "swatch")
      assert swatch.props[:background] == "#ffffff"
    end

    test "black at s=0, v=0" do
      model = %{hue: 0.0, saturation: 0.0, value: 0.0}
      tree = ColorPicker.view(model)
      swatch = Plushie.UI.find(tree, "swatch")
      assert swatch.props[:background] == "#000000"
    end

    test "HSV display text shows correct values" do
      model = %{hue: 210.0, saturation: 0.85, value: 0.92}
      tree = ColorPicker.view(model)
      hsv_text = Plushie.UI.find(tree, "hsv_display")
      content = hsv_text.props[:content]
      assert content =~ "H: 210"
      assert content =~ "S: 85%"
      assert content =~ "V: 92%"
    end
  end

  # ---------------------------------------------------------------------------
  # view/1 -- a11y
  # ---------------------------------------------------------------------------

  describe "view/1 -- accessibility" do
    test "swatch has image role with color label" do
      tree = ColorPicker.view(ColorPicker.init([]))
      swatch = Plushie.UI.find(tree, "swatch")
      a11y = swatch.props[:a11y]
      assert a11y.role == :image
      assert a11y.label =~ "#ff0000"
    end

    test "hex display has live region" do
      tree = ColorPicker.view(ColorPicker.init([]))
      hex_text = Plushie.UI.find(tree, "hex_display")
      assert hex_text.props[:a11y].live == :polite
    end

    test "hex display is busy at initial state" do
      tree = ColorPicker.view(ColorPicker.init([]))
      hex_text = Plushie.UI.find(tree, "hex_display")
      assert hex_text.props[:a11y].busy == true
    end

    test "hex display is not busy after first change" do
      model = %{hue: 30.0, saturation: 0.9, value: 0.8}
      tree = ColorPicker.view(model)
      hex_text = Plushie.UI.find(tree, "hex_display")
      assert hex_text.props[:a11y].busy == false
    end
  end

  # ---------------------------------------------------------------------------
  # Full cycle
  # ---------------------------------------------------------------------------

  describe "full cycle" do
    test "change event -> view reflects new color" do
      model =
        ColorPicker.init([])
        |> ColorPicker.update(%Widget{
          type: :change,
          id: "picker",
          data: %{"hue" => 180.0, "saturation" => 0.5, "value" => 0.5}
        })

      tree = ColorPicker.view(model)
      swatch = Plushie.UI.find(tree, "swatch")
      assert is_binary(swatch.props[:background])
      assert String.starts_with?(swatch.props[:background], "#")

      hex_text = Plushie.UI.find(tree, "hex_display")
      assert hex_text.props[:content] == swatch.props[:background]
    end
  end
end
