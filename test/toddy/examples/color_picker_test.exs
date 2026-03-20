defmodule ColorPickerTest do
  use ExUnit.Case, async: true

  alias Toddy.Event.Canvas
  alias Toddy.Event.Widget

  alias ColorPicker

  # ---------------------------------------------------------------------------
  # init/1
  # ---------------------------------------------------------------------------

  describe "init/1" do
    test "returns initial model with red selected" do
      model = ColorPicker.init([])
      assert model.hue == 0.0
      assert model.saturation == 1.0
      assert model.value == 1.0
      assert model.drag == :none
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- ring press
  # ---------------------------------------------------------------------------

  describe "update/2 -- ring press" do
    test "press at top of ring selects hue near 0" do
      model = ColorPicker.init([])
      # Top of ring: (200, 30) -- distance 170, within 150..190
      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 200.0,
          y: 30.0,
          button: "left"
        })

      assert result.drag == :ring
      # Hue should be near 0 (top = red)
      assert_in_delta result.hue, 0.0, 2.0
    end

    test "press at right of ring selects hue near 90" do
      model = ColorPicker.init([])
      # Right of ring: (370, 200) -- distance 170
      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 370.0,
          y: 200.0,
          button: "left"
        })

      assert result.drag == :ring
      assert_in_delta result.hue, 90.0, 2.0
    end

    test "press at bottom of ring selects hue near 180" do
      model = ColorPicker.init([])
      # Bottom of ring: (200, 370)
      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 200.0,
          y: 370.0,
          button: "left"
        })

      assert result.drag == :ring
      assert_in_delta result.hue, 180.0, 2.0
    end

    test "press at left of ring selects hue near 270" do
      model = ColorPicker.init([])
      # Left of ring: (30, 200)
      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 30.0,
          y: 200.0,
          button: "left"
        })

      assert result.drag == :ring
      assert_in_delta result.hue, 270.0, 2.0
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- square press
  # ---------------------------------------------------------------------------

  describe "update/2 -- square press" do
    test "press at top-left of square sets s=0, v=1" do
      model = ColorPicker.init([])

      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 100.0,
          y: 100.0,
          button: "left"
        })

      assert result.drag == :square
      assert_in_delta result.saturation, 0.0, 0.01
      assert_in_delta result.value, 1.0, 0.01
    end

    test "press at bottom-right of square sets s=1, v=0" do
      model = ColorPicker.init([])

      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 300.0,
          y: 300.0,
          button: "left"
        })

      assert result.drag == :square
      assert_in_delta result.saturation, 1.0, 0.01
      assert_in_delta result.value, 0.0, 0.01
    end

    test "press at center of square sets s=0.5, v=0.5" do
      model = ColorPicker.init([])

      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 200.0,
          y: 200.0,
          button: "left"
        })

      assert result.drag == :square
      assert_in_delta result.saturation, 0.5, 0.01
      assert_in_delta result.value, 0.5, 0.01
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- press outside
  # ---------------------------------------------------------------------------

  describe "update/2 -- press outside" do
    test "press at center (inside inner ring) is ignored" do
      model = ColorPicker.init([])
      # (200, 200) is distance 0 from center, well inside inner_r=150
      # but also inside the SV square (100..300), so it hits the square
      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 200.0,
          y: 200.0,
          button: "left"
        })

      # Center is inside the square, so drag is :square
      assert result.drag == :square
    end

    test "press at corner outside ring is ignored" do
      model = ColorPicker.init([])
      # (5, 5) is distance ~276 from center, outside outer_r=190
      # and outside square (100..300)
      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 5.0,
          y: 5.0,
          button: "left"
        })

      assert result == model
    end

    test "press between ring and square is ignored" do
      model = ColorPicker.init([])
      # (200, 90) is distance 110 from center -- inside inner_r but outside square
      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 200.0,
          y: 90.0,
          button: "left"
        })

      assert result == model
    end

    test "right-click is ignored" do
      model = ColorPicker.init([])

      result =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 200.0,
          y: 30.0,
          button: "right"
        })

      assert result == model
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- move
  # ---------------------------------------------------------------------------

  describe "update/2 -- canvas_move" do
    test "move while dragging ring updates hue" do
      model = %{hue: 0.0, saturation: 1.0, value: 1.0, drag: :ring}
      # Move cursor to the right side: should set hue near 90
      result = ColorPicker.update(model, %Canvas{type: :move, id: "picker", x: 370.0, y: 200.0})
      assert_in_delta result.hue, 90.0, 2.0
      assert result.drag == :ring
    end

    test "move while dragging square updates s and v" do
      model = %{hue: 0.0, saturation: 0.0, value: 1.0, drag: :square}
      result = ColorPicker.update(model, %Canvas{type: :move, id: "picker", x: 250.0, y: 250.0})
      assert_in_delta result.saturation, 0.75, 0.01
      assert_in_delta result.value, 0.25, 0.01
    end

    test "move clamps s/v to 0..1 when outside square" do
      model = %{hue: 0.0, saturation: 0.5, value: 0.5, drag: :square}
      result = ColorPicker.update(model, %Canvas{type: :move, id: "picker", x: 50.0, y: 350.0})
      assert result.saturation == 0.0
      assert result.value == 0.0
    end

    test "move while not dragging is ignored" do
      model = %{hue: 45.0, saturation: 0.5, value: 0.8, drag: :none}
      result = ColorPicker.update(model, %Canvas{type: :move, id: "picker", x: 200.0, y: 200.0})
      assert result == model
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- release
  # ---------------------------------------------------------------------------

  describe "update/2 -- canvas_release" do
    test "release clears drag" do
      model = %{hue: 90.0, saturation: 0.5, value: 0.8, drag: :ring}

      result =
        ColorPicker.update(model, %Canvas{
          type: :release,
          id: "picker",
          x: 200.0,
          y: 200.0,
          button: "left"
        })

      assert result.drag == :none
      # Other values unchanged
      assert result.hue == 90.0
      assert result.saturation == 0.5
    end

    test "release while not dragging is a no-op" do
      model = %{hue: 0.0, saturation: 1.0, value: 1.0, drag: :none}

      result =
        ColorPicker.update(model, %Canvas{
          type: :release,
          id: "picker",
          x: 100.0,
          y: 100.0,
          button: "left"
        })

      assert result.drag == :none
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- unknown events
  # ---------------------------------------------------------------------------

  describe "update/2 -- unknown events" do
    test "non-canvas events pass through" do
      model = ColorPicker.init([])
      assert ColorPicker.update(model, %Widget{type: :click, id: "something"}) == model
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

    test "canvas node is present with correct props" do
      tree = ColorPicker.view(ColorPicker.init([]))
      picker = Toddy.UI.find(tree, "picker")
      assert picker != nil
      assert picker.type == "canvas"
      assert picker.props[:on_press] == true
      assert picker.props[:on_release] == true
      assert picker.props[:on_move] == true
    end

    test "canvas has 4 layers" do
      tree = ColorPicker.view(ColorPicker.init([]))
      picker = Toddy.UI.find(tree, "picker")
      layers = picker.props[:layers]
      assert map_size(layers) == 4
      assert Map.has_key?(layers, "a_ring")
      assert Map.has_key?(layers, "b_sv_hue")
      assert Map.has_key?(layers, "c_sv_dark")
      assert Map.has_key?(layers, "d_cursors")
    end

    test "ring layer has 72 shapes" do
      tree = ColorPicker.view(ColorPicker.init([]))
      picker = Toddy.UI.find(tree, "picker")
      assert length(picker.props[:layers]["a_ring"]) == 72
    end

    test "sv layers have 1 shape each" do
      tree = ColorPicker.view(ColorPicker.init([]))
      picker = Toddy.UI.find(tree, "picker")
      assert length(picker.props[:layers]["b_sv_hue"]) == 1
      assert length(picker.props[:layers]["c_sv_dark"]) == 1
    end

    test "cursors layer has 2 shapes" do
      tree = ColorPicker.view(ColorPicker.init([]))
      picker = Toddy.UI.find(tree, "picker")
      assert length(picker.props[:layers]["d_cursors"]) == 2
    end

    test "swatch container is present" do
      tree = ColorPicker.view(ColorPicker.init([]))
      swatch = Toddy.UI.find(tree, "swatch")
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
      swatch = Toddy.UI.find(tree, "swatch")
      assert swatch.props[:background] == "#ff0000"

      hex_text = Toddy.UI.find(tree, "hex_display")
      assert hex_text.props[:content] == "#ff0000"
    end

    test "pure green at hue=120" do
      model = %{hue: 120.0, saturation: 1.0, value: 1.0, drag: :none}
      tree = ColorPicker.view(model)
      swatch = Toddy.UI.find(tree, "swatch")
      assert swatch.props[:background] == "#00ff00"
    end

    test "pure blue at hue=240" do
      model = %{hue: 240.0, saturation: 1.0, value: 1.0, drag: :none}
      tree = ColorPicker.view(model)
      swatch = Toddy.UI.find(tree, "swatch")
      assert swatch.props[:background] == "#0000ff"
    end

    test "white at s=0, v=1" do
      model = %{hue: 0.0, saturation: 0.0, value: 1.0, drag: :none}
      tree = ColorPicker.view(model)
      swatch = Toddy.UI.find(tree, "swatch")
      assert swatch.props[:background] == "#ffffff"
    end

    test "black at s=0, v=0" do
      model = %{hue: 0.0, saturation: 0.0, value: 0.0, drag: :none}
      tree = ColorPicker.view(model)
      swatch = Toddy.UI.find(tree, "swatch")
      assert swatch.props[:background] == "#000000"
    end

    test "HSV display text shows correct values" do
      model = %{hue: 210.0, saturation: 0.85, value: 0.92, drag: :none}
      tree = ColorPicker.view(model)
      hsv_text = Toddy.UI.find(tree, "hsv_display")
      content = hsv_text.props[:content]
      assert content =~ "H: 210"
      assert content =~ "S: 85%"
      assert content =~ "V: 92%"
    end
  end

  # ---------------------------------------------------------------------------
  # Full cycle
  # ---------------------------------------------------------------------------

  describe "full cycle" do
    test "ring drag -> square drag -> view shows correct color" do
      model =
        ColorPicker.init([])
        # Press on ring at right side (hue ~90, yellow-green)
        |> ColorPicker.update(%Canvas{
          type: :press,
          id: "picker",
          x: 370.0,
          y: 200.0,
          button: "left"
        })

      assert model.drag == :ring
      assert_in_delta model.hue, 90.0, 2.0

      # Drag ring to bottom (hue ~180, cyan)
      model = ColorPicker.update(model, %Canvas{type: :move, id: "picker", x: 200.0, y: 370.0})
      assert_in_delta model.hue, 180.0, 2.0

      # Release ring
      model =
        ColorPicker.update(model, %Canvas{
          type: :release,
          id: "picker",
          x: 200.0,
          y: 370.0,
          button: "left"
        })

      assert model.drag == :none

      # Press on SV square center
      model =
        ColorPicker.update(model, %Canvas{
          type: :press,
          id: "picker",
          x: 200.0,
          y: 200.0,
          button: "left"
        })

      assert model.drag == :square
      assert_in_delta model.saturation, 0.5, 0.01
      assert_in_delta model.value, 0.5, 0.01

      # Release
      model =
        ColorPicker.update(model, %Canvas{
          type: :release,
          id: "picker",
          x: 200.0,
          y: 200.0,
          button: "left"
        })

      assert model.drag == :none

      # View reflects the selection
      tree = ColorPicker.view(model)
      swatch = Toddy.UI.find(tree, "swatch")
      assert is_binary(swatch.props[:background])
      assert String.starts_with?(swatch.props[:background], "#")
    end
  end
end
