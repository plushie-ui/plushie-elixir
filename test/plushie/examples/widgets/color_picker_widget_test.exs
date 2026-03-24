defmodule ColorPickerWidgetTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.Canvas
  alias Plushie.Event.Widget

  # ---------------------------------------------------------------------------
  # Initial state
  # ---------------------------------------------------------------------------

  describe "__initial_state__/0" do
    test "starts with red, full saturation and value, no drag" do
      state = ColorPickerWidget.__initial_state__()
      assert state.hue == 0.0
      assert state.saturation == 1.0
      assert state.value == 1.0
      assert state.drag == :none
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event -- mouse press on ring
  # ---------------------------------------------------------------------------

  describe "handle_event -- ring press" do
    test "press at top of ring selects hue near 0 and emits :change" do
      state = ColorPickerWidget.__initial_state__()
      # Top of ring: (200, 30) -- distance 170, within 150..190
      result =
        ColorPickerWidget.handle_event(
          %Canvas{type: :press, id: "picker", x: 200.0, y: 30.0, button: "left"},
          state
        )

      assert {:emit, :change, data, new_state} = result
      assert new_state.drag == :ring
      assert_in_delta new_state.hue, 0.0, 2.0
      assert_in_delta data.hue, 0.0, 2.0
      assert data.saturation == 1.0
      assert data.value == 1.0
    end

    test "press at right of ring selects hue near 90" do
      state = ColorPickerWidget.__initial_state__()
      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :press, id: "picker", x: 370.0, y: 200.0, button: "left"},
          state
        )

      assert new_state.drag == :ring
      assert_in_delta new_state.hue, 90.0, 2.0
      assert_in_delta data.hue, 90.0, 2.0
    end

    test "press at bottom of ring selects hue near 180" do
      state = ColorPickerWidget.__initial_state__()
      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :press, id: "picker", x: 200.0, y: 370.0, button: "left"},
          state
        )

      assert new_state.drag == :ring
      assert_in_delta new_state.hue, 180.0, 2.0
      assert_in_delta data.hue, 180.0, 2.0
    end

    test "press at left of ring selects hue near 270" do
      state = ColorPickerWidget.__initial_state__()
      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :press, id: "picker", x: 30.0, y: 200.0, button: "left"},
          state
        )

      assert new_state.drag == :ring
      assert_in_delta new_state.hue, 270.0, 2.0
      assert_in_delta data.hue, 270.0, 2.0
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event -- mouse press on square
  # ---------------------------------------------------------------------------

  describe "handle_event -- square press" do
    test "press at top-left of square sets s=0, v=1" do
      state = ColorPickerWidget.__initial_state__()
      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :press, id: "picker", x: 100.0, y: 100.0, button: "left"},
          state
        )

      assert new_state.drag == :square
      assert_in_delta new_state.saturation, 0.0, 0.01
      assert_in_delta new_state.value, 1.0, 0.01
      assert_in_delta data.saturation, 0.0, 0.01
      assert_in_delta data.value, 1.0, 0.01
    end

    test "press at bottom-right of square sets s=1, v=0" do
      state = ColorPickerWidget.__initial_state__()
      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :press, id: "picker", x: 300.0, y: 300.0, button: "left"},
          state
        )

      assert new_state.drag == :square
      assert_in_delta new_state.saturation, 1.0, 0.01
      assert_in_delta new_state.value, 0.0, 0.01
      assert_in_delta data.saturation, 1.0, 0.01
      assert_in_delta data.value, 0.0, 0.01
    end

    test "press at center of square sets s=0.5, v=0.5" do
      state = ColorPickerWidget.__initial_state__()
      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :press, id: "picker", x: 200.0, y: 200.0, button: "left"},
          state
        )

      assert new_state.drag == :square
      assert_in_delta new_state.saturation, 0.5, 0.01
      assert_in_delta new_state.value, 0.5, 0.01
      assert_in_delta data.saturation, 0.5, 0.01
      assert_in_delta data.value, 0.5, 0.01
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event -- press outside
  # ---------------------------------------------------------------------------

  describe "handle_event -- press outside" do
    test "press at corner outside ring and square is consumed" do
      state = ColorPickerWidget.__initial_state__()
      # (5, 5) is distance ~276 from center, outside outer_r=190 and outside square
      assert :consumed =
               ColorPickerWidget.handle_event(
                 %Canvas{type: :press, id: "picker", x: 5.0, y: 5.0, button: "left"},
                 state
               )
    end

    test "press between ring and square is consumed" do
      state = ColorPickerWidget.__initial_state__()
      # (200, 90) is distance 110 from center -- inside inner_r but outside square
      assert :consumed =
               ColorPickerWidget.handle_event(
                 %Canvas{type: :press, id: "picker", x: 200.0, y: 90.0, button: "left"},
                 state
               )
    end

    test "right-click is consumed" do
      state = ColorPickerWidget.__initial_state__()
      assert :consumed =
               ColorPickerWidget.handle_event(
                 %Canvas{type: :press, id: "picker", x: 200.0, y: 30.0, button: "right"},
                 state
               )
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event -- drag (move)
  # ---------------------------------------------------------------------------

  describe "handle_event -- move" do
    test "move while dragging ring updates hue and emits :change" do
      state = %{ColorPickerWidget.__initial_state__() | drag: :ring}
      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :move, id: "picker", x: 370.0, y: 200.0},
          state
        )

      assert_in_delta new_state.hue, 90.0, 2.0
      assert_in_delta data.hue, 90.0, 2.0
      assert new_state.drag == :ring
    end

    test "move while dragging square updates s and v" do
      state = %{ColorPickerWidget.__initial_state__() | drag: :square, saturation: 0.0}
      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :move, id: "picker", x: 250.0, y: 250.0},
          state
        )

      assert_in_delta new_state.saturation, 0.75, 0.01
      assert_in_delta new_state.value, 0.25, 0.01
      assert_in_delta data.saturation, 0.75, 0.01
      assert_in_delta data.value, 0.25, 0.01
    end

    test "move clamps s/v to 0..1 when outside square" do
      state = %{ColorPickerWidget.__initial_state__() | drag: :square, saturation: 0.5, value: 0.5}
      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :move, id: "picker", x: 50.0, y: 350.0},
          state
        )

      assert new_state.saturation == 0.0
      assert new_state.value == 0.0
    end

    test "move while not dragging is consumed" do
      state = ColorPickerWidget.__initial_state__()
      assert :consumed =
               ColorPickerWidget.handle_event(
                 %Canvas{type: :move, id: "picker", x: 200.0, y: 200.0},
                 state
               )
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event -- release
  # ---------------------------------------------------------------------------

  describe "handle_event -- release" do
    test "release clears drag state" do
      state = %{ColorPickerWidget.__initial_state__() | drag: :ring, hue: 90.0}
      {:update_state, new_state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :release, id: "picker", x: 200.0, y: 200.0, button: "left"},
          state
        )

      assert new_state.drag == :none
      assert new_state.hue == 90.0
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event -- keyboard (hue cursor)
  # ---------------------------------------------------------------------------

  describe "handle_event -- hue cursor keyboard" do
    test "ArrowRight increments hue by 1 degree" do
      state = %{ColorPickerWidget.__initial_state__() | hue: 45.0}

      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "hue-cursor", data: %{"key" => "ArrowRight", "modifiers" => %{}}},
          state
        )

      assert_in_delta new_state.hue, 46.0, 0.01
      assert_in_delta data.hue, 46.0, 0.01
    end

    test "ArrowLeft decrements hue by 1 degree" do
      state = %{ColorPickerWidget.__initial_state__() | hue: 45.0}

      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "hue-cursor", data: %{"key" => "ArrowLeft", "modifiers" => %{}}},
          state
        )

      assert_in_delta new_state.hue, 44.0, 0.01
      assert_in_delta data.hue, 44.0, 0.01
    end

    test "Shift+ArrowRight increments hue by 15 degrees" do
      state = %{ColorPickerWidget.__initial_state__() | hue: 45.0}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "hue-cursor", data: %{"key" => "ArrowRight", "modifiers" => %{"shift" => true}}},
          state
        )

      assert_in_delta new_state.hue, 60.0, 0.01
    end

    test "hue wraps around 360" do
      state = %{ColorPickerWidget.__initial_state__() | hue: 359.5}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "hue-cursor", data: %{"key" => "ArrowRight", "modifiers" => %{}}},
          state
        )

      assert_in_delta new_state.hue, 0.5, 0.01
    end

    test "hue wraps below 0" do
      state = %{ColorPickerWidget.__initial_state__() | hue: 0.5}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "hue-cursor", data: %{"key" => "ArrowLeft", "modifiers" => %{}}},
          state
        )

      assert_in_delta new_state.hue, 359.5, 0.01
    end

    test "Home sets hue to 0" do
      state = %{ColorPickerWidget.__initial_state__() | hue: 180.0}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "hue-cursor", data: %{"key" => "Home", "modifiers" => %{}}},
          state
        )

      assert new_state.hue == 0.0
    end

    test "End sets hue to 359" do
      state = ColorPickerWidget.__initial_state__()

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "hue-cursor", data: %{"key" => "End", "modifiers" => %{}}},
          state
        )

      assert new_state.hue == 359.0
    end

    test "PageUp increments by coarse step (15)" do
      state = %{ColorPickerWidget.__initial_state__() | hue: 30.0}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "hue-cursor", data: %{"key" => "PageUp", "modifiers" => %{}}},
          state
        )

      assert_in_delta new_state.hue, 45.0, 0.01
    end

    test "unrecognized key is consumed" do
      state = %{ColorPickerWidget.__initial_state__() | hue: 45.0}

      assert :consumed =
               ColorPickerWidget.handle_event(
                 %Widget{type: :canvas_element_key_press, id: "hue-cursor", data: %{"key" => "a", "modifiers" => %{}}},
                 state
               )
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event -- keyboard (sv cursor)
  # ---------------------------------------------------------------------------

  describe "handle_event -- sv cursor keyboard" do
    test "ArrowRight increases saturation by fine step" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.5, value: 0.5}

      {:emit, :change, data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "ArrowRight", "modifiers" => %{}}},
          state
        )

      assert_in_delta new_state.saturation, 0.51, 0.001
      assert new_state.value == 0.5
      assert_in_delta data.saturation, 0.51, 0.001
    end

    test "ArrowLeft decreases saturation" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.5, value: 0.5}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "ArrowLeft", "modifiers" => %{}}},
          state
        )

      assert_in_delta new_state.saturation, 0.49, 0.001
    end

    test "ArrowUp increases value (brightness)" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.5, value: 0.5}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "ArrowUp", "modifiers" => %{}}},
          state
        )

      assert new_state.saturation == 0.5
      assert_in_delta new_state.value, 0.51, 0.001
    end

    test "ArrowDown decreases value" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.5, value: 0.5}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "ArrowDown", "modifiers" => %{}}},
          state
        )

      assert_in_delta new_state.value, 0.49, 0.001
    end

    test "Shift+ArrowRight increases saturation by coarse step" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.5, value: 0.5}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "ArrowRight", "modifiers" => %{"shift" => true}}},
          state
        )

      assert_in_delta new_state.saturation, 0.6, 0.001
    end

    test "saturation clamps to 0..1" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 1.0, value: 0.5}

      assert :consumed =
               ColorPickerWidget.handle_event(
                 %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "ArrowRight", "modifiers" => %{}}},
                 state
               )
    end

    test "value clamps to 0..1" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.5, value: 0.0}

      assert :consumed =
               ColorPickerWidget.handle_event(
                 %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "ArrowDown", "modifiers" => %{}}},
                 state
               )
    end

    test "Shift+Home sets saturation to 0" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.8, value: 0.5}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "Home", "modifiers" => %{"shift" => true}}},
          state
        )

      assert new_state.saturation == 0.0
      assert new_state.value == 0.5
    end

    test "Shift+End sets saturation to 1" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.3, value: 0.5}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "End", "modifiers" => %{"shift" => true}}},
          state
        )

      assert new_state.saturation == 1.0
      assert new_state.value == 0.5
    end

    test "Home (without shift) sets value to 1" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.5, value: 0.3}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "Home", "modifiers" => %{}}},
          state
        )

      assert new_state.saturation == 0.5
      assert new_state.value == 1.0
    end

    test "End (without shift) sets value to 0" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.5, value: 0.8}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "End", "modifiers" => %{}}},
          state
        )

      assert new_state.saturation == 0.5
      assert new_state.value == 0.0
    end

    test "Shift+PageUp adjusts saturation by coarse step" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.5, value: 0.5}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "PageUp", "modifiers" => %{"shift" => true}}},
          state
        )

      assert_in_delta new_state.saturation, 0.6, 0.001
      assert new_state.value == 0.5
    end

    test "PageUp (without shift) adjusts value by coarse step" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.5, value: 0.5}

      {:emit, :change, _data, new_state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "sv-cursor", data: %{"key" => "PageUp", "modifiers" => %{}}},
          state
        )

      assert new_state.saturation == 0.5
      assert_in_delta new_state.value, 0.6, 0.001
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event -- unknown element key press
  # ---------------------------------------------------------------------------

  describe "handle_event -- unknown element" do
    test "key press on unknown element is consumed" do
      state = ColorPickerWidget.__initial_state__()

      assert :consumed =
               ColorPickerWidget.handle_event(
                 %Widget{type: :canvas_element_key_press, id: "nonexistent", data: %{"key" => "ArrowRight", "modifiers" => %{}}},
                 state
               )
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event -- catchall
  # ---------------------------------------------------------------------------

  describe "handle_event -- unrecognized events" do
    test "unknown event types are consumed" do
      state = ColorPickerWidget.__initial_state__()
      assert :consumed = ColorPickerWidget.handle_event(%Widget{type: :click, id: "x"}, state)
    end
  end

  # ---------------------------------------------------------------------------
  # render/3
  # ---------------------------------------------------------------------------

  describe "render/3" do
    test "produces a canvas node with correct dimensions" do
      state = ColorPickerWidget.__initial_state__()
      node = ColorPickerWidget.render("picker", %{}, state)
      assert node.type == "canvas"
      assert node.id == "picker"
      assert node.props[:width] == 400
      assert node.props[:height] == 400
    end

    test "canvas has 4 layers" do
      state = ColorPickerWidget.__initial_state__()
      node = ColorPickerWidget.render("picker", %{}, state)
      layers = node.props[:layers]
      assert map_size(layers) == 4
      assert Map.has_key?(layers, "a_ring")
      assert Map.has_key?(layers, "b_sv_hue")
      assert Map.has_key?(layers, "c_sv_dark")
      assert Map.has_key?(layers, "d_cursors")
    end

    test "ring layer has 72 segments" do
      state = ColorPickerWidget.__initial_state__()
      node = ColorPickerWidget.render("picker", %{}, state)
      assert length(node.props[:layers]["a_ring"]) == 72
    end

    test "cursors layer has hue-cursor and sv-cursor groups" do
      state = ColorPickerWidget.__initial_state__()
      node = ColorPickerWidget.render("picker", %{}, state)
      cursors = node.props[:layers]["d_cursors"]
      assert length(cursors) == 2

      ids = Enum.map(cursors, & &1.id)
      assert "hue-cursor" in ids
      assert "sv-cursor" in ids
    end

    test "cursor a11y declares slider role" do
      state = ColorPickerWidget.__initial_state__()
      node = ColorPickerWidget.render("picker", %{}, state)
      cursors = node.props[:layers]["d_cursors"]
      hue = Enum.find(cursors, &(&1.id == "hue-cursor"))
      sv = Enum.find(cursors, &(&1.id == "sv-cursor"))

      assert hue.a11y[:role] == :slider
      assert hue.a11y[:label] == "Hue"
      assert sv.a11y[:role] == :slider
      assert sv.a11y[:label] == "Saturation and brightness"
    end

    test "hue cursor value reflects state" do
      state = %{ColorPickerWidget.__initial_state__() | hue: 120.0}
      node = ColorPickerWidget.render("picker", %{}, state)
      cursors = node.props[:layers]["d_cursors"]
      hue = Enum.find(cursors, &(&1.id == "hue-cursor"))
      assert hue.a11y[:value] == "120 degrees"
    end

    test "sv cursor value reflects state" do
      state = %{ColorPickerWidget.__initial_state__() | saturation: 0.75, value: 0.6}
      node = ColorPickerWidget.render("picker", %{}, state)
      cursors = node.props[:layers]["d_cursors"]
      sv = Enum.find(cursors, &(&1.id == "sv-cursor"))
      assert sv.a11y[:value] == "75% saturation, 60% brightness"
    end
  end

  # ---------------------------------------------------------------------------
  # Full interaction cycle
  # ---------------------------------------------------------------------------

  describe "full interaction cycle" do
    test "ring drag -> square drag -> keyboard adjust" do
      state = ColorPickerWidget.__initial_state__()

      # Press on ring at right side (hue ~90)
      {:emit, :change, _data, state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :press, id: "picker", x: 370.0, y: 200.0, button: "left"},
          state
        )

      assert state.drag == :ring
      assert_in_delta state.hue, 90.0, 2.0

      # Drag ring to bottom (hue ~180)
      {:emit, :change, _data, state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :move, id: "picker", x: 200.0, y: 370.0},
          state
        )

      assert_in_delta state.hue, 180.0, 2.0

      # Release
      {:update_state, state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :release, id: "picker", x: 200.0, y: 370.0, button: "left"},
          state
        )

      assert state.drag == :none

      # Press on SV square center
      {:emit, :change, _data, state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :press, id: "picker", x: 200.0, y: 200.0, button: "left"},
          state
        )

      assert state.drag == :square
      assert_in_delta state.saturation, 0.5, 0.01

      # Release
      {:update_state, state} =
        ColorPickerWidget.handle_event(
          %Canvas{type: :release, id: "picker", x: 200.0, y: 200.0, button: "left"},
          state
        )

      # Now adjust with keyboard
      {:emit, :change, data, state} =
        ColorPickerWidget.handle_event(
          %Widget{type: :canvas_element_key_press, id: "hue-cursor", data: %{"key" => "ArrowRight", "modifiers" => %{}}},
          state
        )

      # Hue moved by 1 degree from ~180
      assert_in_delta state.hue, 181.0, 2.0
      assert_in_delta data.hue, 181.0, 2.0
    end
  end
end
