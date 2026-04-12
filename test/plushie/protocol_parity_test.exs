defmodule Plushie.ProtocolParityTest do
  @moduledoc """
  Tests for all new protocol event decoders added in the iced parity pass.
  Does not duplicate tests from protocol_test.exs -- only covers new events.
  """
  use ExUnit.Case, async: true

  alias Plushie.Event.KeyEvent
  alias Plushie.Event.ModifiersEvent
  alias Plushie.Event.SystemEvent
  alias Plushie.Event.WidgetEvent
  alias Plushie.Event.WindowEvent

  alias Plushie.Protocol

  describe "key_press event decoding" do
    test "decodes named key with modifiers (key in data)" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false},
          value: %{key: "Escape"}
        })

      assert %KeyEvent{type: :press, key: :escape, modifiers: %Plushie.KeyModifiers{ctrl: false}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes character key" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: false},
          value: %{key: "a"}
        })

      assert %KeyEvent{type: :press, key: "a", modifiers: %Plushie.KeyModifiers{ctrl: true}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes with ctrl+shift modifiers" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: true, shift: true, alt: false, logo: false, command: false},
          value: %{key: "Tab"}
        })

      assert %KeyEvent{
               type: :press,
               key: :tab,
               modifiers: %Plushie.KeyModifiers{ctrl: true, shift: true}
             } = Protocol.decode_message(json, :json)
    end
  end

  describe "key_release event decoding" do
    test "decodes named key release (key in data)" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_release",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false},
          value: %{key: "Control"}
        })

      assert %KeyEvent{type: :release, key: :control} = Protocol.decode_message(json, :json)
    end
  end

  describe "wheel scroll decoding" do
    test "rejects unknown units as protocol errors" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "wheel_scrolled",
          value: %{delta_x: 1, delta_y: 2, unit: "page"}
        })

      assert {:error, {:invalid_event_field, "wheel_scrolled", :unit, "page", :unknown, _}} =
               Protocol.decode_message(json, :json)
    end

    test "rejects malformed non-string units as protocol errors" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "wheel_scrolled",
          value: %{delta_x: 1, delta_y: 2, unit: 123}
        })

      assert {:error, {:invalid_event_field, "wheel_scrolled", :unit, 123, :invalid, _}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "parse_key/1" do
    # Navigation
    test "maps Escape" do
      assert Protocol.parse_key("Escape") == :escape
    end

    test "maps Enter" do
      assert Protocol.parse_key("Enter") == :enter
    end

    test "maps Tab" do
      assert Protocol.parse_key("Tab") == :tab
    end

    test "maps Backspace" do
      assert Protocol.parse_key("Backspace") == :backspace
    end

    test "maps Delete" do
      assert Protocol.parse_key("Delete") == :delete
    end

    test "maps ArrowUp" do
      assert Protocol.parse_key("ArrowUp") == :arrow_up
    end

    test "maps ArrowDown" do
      assert Protocol.parse_key("ArrowDown") == :arrow_down
    end

    test "maps ArrowLeft" do
      assert Protocol.parse_key("ArrowLeft") == :arrow_left
    end

    test "maps ArrowRight" do
      assert Protocol.parse_key("ArrowRight") == :arrow_right
    end

    test "maps Home" do
      assert Protocol.parse_key("Home") == :home
    end

    test "maps End" do
      assert Protocol.parse_key("End") == :end
    end

    test "maps PageUp" do
      assert Protocol.parse_key("PageUp") == :page_up
    end

    test "maps PageDown" do
      assert Protocol.parse_key("PageDown") == :page_down
    end

    test "maps Space" do
      assert Protocol.parse_key("Space") == :space
    end

    test "maps Insert" do
      assert Protocol.parse_key("Insert") == :insert
    end

    test "maps Clear" do
      assert Protocol.parse_key("Clear") == :clear
    end

    # Modifier keys
    test "maps Alt" do
      assert Protocol.parse_key("Alt") == :alt
    end

    test "maps AltGraph" do
      assert Protocol.parse_key("AltGraph") == :alt_graph
    end

    test "maps CapsLock" do
      assert Protocol.parse_key("CapsLock") == :caps_lock
    end

    test "maps Control" do
      assert Protocol.parse_key("Control") == :control
    end

    test "maps Shift" do
      assert Protocol.parse_key("Shift") == :shift
    end

    test "maps Meta" do
      assert Protocol.parse_key("Meta") == :meta
    end

    test "maps NumLock" do
      assert Protocol.parse_key("NumLock") == :num_lock
    end

    test "maps ScrollLock" do
      assert Protocol.parse_key("ScrollLock") == :scroll_lock
    end

    test "maps Super" do
      assert Protocol.parse_key("Super") == :super_key
    end

    test "maps Hyper" do
      assert Protocol.parse_key("Hyper") == :hyper
    end

    # Editing keys
    test "maps Copy" do
      assert Protocol.parse_key("Copy") == :copy
    end

    test "maps Cut" do
      assert Protocol.parse_key("Cut") == :cut
    end

    test "maps Paste" do
      assert Protocol.parse_key("Paste") == :paste
    end

    test "maps Undo" do
      assert Protocol.parse_key("Undo") == :undo
    end

    test "maps Redo" do
      assert Protocol.parse_key("Redo") == :redo
    end

    # Function keys (sampling F1, F12, F13, F24, F35)
    test "maps F1" do
      assert Protocol.parse_key("F1") == :f1
    end

    test "maps F12" do
      assert Protocol.parse_key("F12") == :f12
    end

    test "maps F13" do
      assert Protocol.parse_key("F13") == :f13
    end

    test "maps F24" do
      assert Protocol.parse_key("F24") == :f24
    end

    test "maps F35" do
      assert Protocol.parse_key("F35") == :f35
    end

    # Media keys
    test "maps MediaPlay" do
      assert Protocol.parse_key("MediaPlay") == :media_play
    end

    test "maps MediaStop" do
      assert Protocol.parse_key("MediaStop") == :media_stop
    end

    test "maps MediaTrackNext" do
      assert Protocol.parse_key("MediaTrackNext") == :media_track_next
    end

    test "maps MediaPlayPause" do
      assert Protocol.parse_key("MediaPlayPause") == :media_play_pause
    end

    # Audio keys
    test "maps AudioVolumeUp" do
      assert Protocol.parse_key("AudioVolumeUp") == :audio_volume_up
    end

    test "maps AudioVolumeDown" do
      assert Protocol.parse_key("AudioVolumeDown") == :audio_volume_down
    end

    test "maps AudioVolumeMute" do
      assert Protocol.parse_key("AudioVolumeMute") == :audio_volume_mute
    end

    # Browser keys
    test "maps BrowserBack" do
      assert Protocol.parse_key("BrowserBack") == :browser_back
    end

    test "maps BrowserForward" do
      assert Protocol.parse_key("BrowserForward") == :browser_forward
    end

    test "maps BrowserRefresh" do
      assert Protocol.parse_key("BrowserRefresh") == :browser_refresh
    end

    # System keys
    test "maps PrintScreen" do
      assert Protocol.parse_key("PrintScreen") == :print_screen
    end

    test "maps Power" do
      assert Protocol.parse_key("Power") == :power
    end

    # IME keys
    test "maps Convert" do
      assert Protocol.parse_key("Convert") == :convert
    end

    test "maps NonConvert" do
      assert Protocol.parse_key("NonConvert") == :non_convert
    end

    test "maps Compose" do
      assert Protocol.parse_key("Compose") == :compose
    end

    # Launch keys
    test "maps LaunchMail" do
      assert Protocol.parse_key("LaunchMail") == :launch_mail
    end

    test "maps LaunchWebBrowser" do
      assert Protocol.parse_key("LaunchWebBrowser") == :launch_web_browser
    end

    # TV keys
    test "maps TV" do
      assert Protocol.parse_key("TV") == :tv
    end

    # Numpad keys
    test "maps NumpadEnter" do
      assert Protocol.parse_key("NumpadEnter") == :numpad_enter
    end

    test "maps NumpadDecimal" do
      assert Protocol.parse_key("NumpadDecimal") == :numpad_decimal
    end

    # Unidentified
    test "maps Unidentified" do
      assert Protocol.parse_key("Unidentified") == :unidentified
    end

    # Single character keys pass through as strings
    test "passes through single character key" do
      assert Protocol.parse_key("a") == "a"
    end

    test "passes through number character key" do
      assert Protocol.parse_key("1") == "1"
    end

    test "passes through unknown string" do
      assert Protocol.parse_key("SomethingNew") == "SomethingNew"
    end
  end

  describe "cursor_moved event" do
    test "decodes cursor position as WidgetEvent" do
      json = Jason.encode!(%{type: "event", family: "cursor_moved", value: %{x: 100.5, y: 200.3}})

      assert %WidgetEvent{type: :move, id: "__global__", scope: [], value: data} =
               Protocol.decode_message(json, :json)

      assert data.x == 100.5
      assert data.y == 200.3
      assert data.pointer == :mouse
      assert data.captured == false
    end

    test "decodes integer coordinates" do
      json = Jason.encode!(%{type: "event", family: "cursor_moved", value: %{x: 0, y: 0}})

      assert %WidgetEvent{type: :move, value: %{x: 0, y: 0}} =
               Protocol.decode_message(json, :json)
    end

    test "includes window_id when present" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "cursor_moved",
          value: %{x: 1.0, y: 2.0},
          window_id: "main"
        })

      assert %WidgetEvent{type: :move, id: "main", window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "cursor_entered event" do
    test "decodes cursor entered as WidgetEvent" do
      json = Jason.encode!(%{type: "event", family: "cursor_entered"})

      assert %WidgetEvent{type: :enter, id: "__global__", scope: []} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "cursor_left event" do
    test "decodes cursor left as WidgetEvent" do
      json = Jason.encode!(%{type: "event", family: "cursor_left"})

      assert %WidgetEvent{type: :exit, id: "__global__", scope: []} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "button_pressed event" do
    test "decodes mouse button press as WidgetEvent" do
      json = Jason.encode!(%{type: "event", family: "button_pressed", value: "left"})

      assert %WidgetEvent{type: :press, id: "__global__", scope: [], value: data} =
               Protocol.decode_message(json, :json)

      assert data.button == :left
      assert data.pointer == :mouse
      assert data.captured == false
    end

    test "decodes right button press" do
      json = Jason.encode!(%{type: "event", family: "button_pressed", value: "right"})

      assert %WidgetEvent{type: :press, value: %{button: :right}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "button_released event" do
    test "decodes mouse button release as WidgetEvent" do
      json = Jason.encode!(%{type: "event", family: "button_released", value: "left"})

      assert %WidgetEvent{type: :release, value: %{button: :left, pointer: :mouse}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "wheel_scrolled event" do
    test "decodes scroll with delta and unit" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "wheel_scrolled",
          value: %{delta_x: 0.0, delta_y: -3.0, unit: "line"}
        })

      assert %WidgetEvent{type: :scroll, value: data} = Protocol.decode_message(json, :json)
      assert data.delta_x == +0.0
      assert data.delta_y == -3.0
      assert data.unit == :line
      assert data.pointer == :mouse
      assert data.captured == false
    end

    test "decodes pixel scroll unit" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "wheel_scrolled",
          value: %{delta_x: 10.0, delta_y: 20.0, unit: "pixel"}
        })

      assert %WidgetEvent{type: :scroll, value: %{unit: :pixel, delta_x: 10.0, delta_y: 20.0}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "finger_pressed event" do
    test "decodes finger press as WidgetEvent" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_pressed",
          value: %{id: 0, x: 50.0, y: 75.0}
        })

      assert %WidgetEvent{type: :press, value: data} = Protocol.decode_message(json, :json)
      assert data.pointer == :touch
      assert data.finger == 0
      assert data.x == 50.0
      assert data.y == 75.0
      assert data.captured == false
    end
  end

  describe "finger_moved event" do
    test "decodes finger move as WidgetEvent" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_moved",
          value: %{id: 1, x: 60.0, y: 80.0}
        })

      assert %WidgetEvent{type: :move, value: %{pointer: :touch, finger: 1, x: 60.0, y: 80.0}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "finger_lifted event" do
    test "decodes finger lift as WidgetEvent" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_lifted",
          value: %{id: 0, x: 55.0, y: 70.0}
        })

      assert %WidgetEvent{
               type: :release,
               value: %{pointer: :touch, finger: 0, x: 55.0, y: 70.0}
             } = Protocol.decode_message(json, :json)
    end
  end

  describe "finger_lost event" do
    test "decodes finger lost as WidgetEvent release with lost flag" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_lost",
          value: %{id: 2, x: 30.0, y: 40.0}
        })

      assert %WidgetEvent{type: :release, value: data} = Protocol.decode_message(json, :json)
      assert data.pointer == :touch
      assert data.finger == 2
      assert data.lost == true
    end
  end

  describe "window_opened event" do
    test "decodes window opened with position, size, and scale_factor" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_opened",
          value: %{
            window_id: "main",
            position: %{x: 100, y: 200},
            width: 800,
            height: 600,
            scale_factor: 2.0
          }
        })

      assert %WindowEvent{
               type: :opened,
               window_id: "main",
               position: {100, 200},
               width: 800,
               height: 600,
               scale_factor: 2.0
             } =
               Protocol.decode_message(json, :json)
    end

    test "decodes window opened with nil position" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_opened",
          value: %{window_id: "main", position: nil, width: 1024, height: 768, scale_factor: 1.0}
        })

      assert %WindowEvent{
               type: :opened,
               window_id: "main",
               position: nil,
               width: 1024,
               height: 768,
               scale_factor: 1.0
             } =
               Protocol.decode_message(json, :json)
    end
  end

  describe "window_closed event" do
    test "decodes window closed" do
      json =
        Jason.encode!(%{type: "event", family: "window_closed", value: %{window_id: "settings"}})

      assert %WindowEvent{type: :closed, window_id: "settings"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "window_moved event" do
    test "decodes window moved with coordinates" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_moved",
          value: %{window_id: "main", x: 300, y: 150}
        })

      assert %WindowEvent{type: :moved, window_id: "main", x: 300, y: 150} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "window_resized event" do
    test "decodes window resized with dimensions" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_resized",
          value: %{window_id: "main", width: 1920, height: 1080}
        })

      assert %WindowEvent{type: :resized, window_id: "main", width: 1920, height: 1080} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "window_focused event" do
    test "decodes window focused" do
      json =
        Jason.encode!(%{type: "event", family: "window_focused", value: %{window_id: "main"}})

      assert %WindowEvent{type: :focused, window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "window_unfocused event" do
    test "decodes window unfocused" do
      json =
        Jason.encode!(%{type: "event", family: "window_unfocused", value: %{window_id: "main"}})

      assert %WindowEvent{type: :unfocused, window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "window_rescaled event" do
    test "decodes window rescaled with scale factor" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_rescaled",
          value: %{window_id: "main", scale_factor: 2.0}
        })

      assert %WindowEvent{type: :rescaled, window_id: "main", scale_factor: 2.0} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "window_close_requested event" do
    test "decodes window close request" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_close_requested",
          value: %{window_id: "main"}
        })

      assert %WindowEvent{type: :close_requested, window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "file_hovered event" do
    test "decodes file hovered over window" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "file_hovered",
          value: %{window_id: "main", path: "/tmp/test.txt"}
        })

      assert %WindowEvent{type: :file_hovered, window_id: "main", path: "/tmp/test.txt"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "file_dropped event" do
    test "decodes file dropped on window" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "file_dropped",
          value: %{window_id: "main", path: "/tmp/image.png"}
        })

      assert %WindowEvent{type: :file_dropped, window_id: "main", path: "/tmp/image.png"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "files_hovered_left event" do
    test "decodes files hovered left" do
      json =
        Jason.encode!(%{type: "event", family: "files_hovered_left", value: %{window_id: "main"}})

      assert %WindowEvent{type: :files_hovered_left, window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "modifiers_changed event" do
    test "decodes modifier state change" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "modifiers_changed",
          modifiers: %{ctrl: true, shift: false, alt: true, logo: false, command: false}
        })

      assert %ModifiersEvent{modifiers: %{ctrl: true, alt: true, shift: false}} =
               Protocol.decode_message(json, :json)
    end

    test "handles missing modifier fields with defaults" do
      json = Jason.encode!(%{type: "event", family: "modifiers_changed", modifiers: %{}})

      assert %ModifiersEvent{
               modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false}
             } =
               Protocol.decode_message(json, :json)
    end
  end

  describe "animation_frame event" do
    test "decodes animation frame with timestamp" do
      json =
        Jason.encode!(%{type: "event", family: "animation_frame", value: %{timestamp: 16_666}})

      assert %SystemEvent{type: :animation_frame, value: 16_666} =
               Protocol.decode_message(json, :json)
    end

    test "decodes float timestamp" do
      json =
        Jason.encode!(%{type: "event", family: "animation_frame", value: %{timestamp: 16.666}})

      assert %SystemEvent{type: :animation_frame, value: 16.666} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "transition_complete event" do
    test "decodes transition complete with tag and prop" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "transition_complete",
          id: "box",
          window_id: "main",
          value: %{tag: "faded_out", prop: "opacity"}
        })

      assert %WidgetEvent{
               type: :transition_complete,
               id: "box",
               scope: ["main"],
               window_id: "main",
               value: %{tag: :faded_out, prop: "opacity"}
             } = Protocol.decode_message(json, :json)
    end

    test "decodes transition complete without tag" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "transition_complete",
          id: "box",
          window_id: "main",
          value: %{prop: "opacity"}
        })

      assert %WidgetEvent{
               type: :transition_complete,
               id: "box",
               scope: ["main"],
               window_id: "main",
               value: %{tag: nil, prop: "opacity"}
             } = Protocol.decode_message(json, :json)
    end
  end

  describe "theme_changed event" do
    test "decodes theme change to dark" do
      json = Jason.encode!(%{type: "event", family: "theme_changed", value: "dark"})

      assert %SystemEvent{type: :theme_changed, value: "dark"} =
               Protocol.decode_message(json, :json)
    end

    test "decodes theme change to light" do
      json = Jason.encode!(%{type: "event", family: "theme_changed", value: "light"})

      assert %SystemEvent{type: :theme_changed, value: "light"} =
               Protocol.decode_message(json, :json)
    end
  end

  # -- Unified pointer events --

  describe "press event decoding" do
    test "decodes left mouse press with coordinates and modifiers" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "press",
          id: "canvas1",
          window_id: "main",
          value: %{
            x: 100.5,
            y: 200.3,
            button: "left",
            pointer: "mouse",
            modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false}
          }
        })

      assert %WidgetEvent{
               type: :press,
               id: "canvas1",
               window_id: "main",
               value: %{
                 x: 100.5,
                 y: 200.3,
                 button: :left,
                 pointer: :mouse,
                 finger: nil,
                 modifiers: %Plushie.KeyModifiers{ctrl: false}
               }
             } = Protocol.decode_message(json, :json)
    end

    test "decodes right button press" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "press",
          id: "area",
          window_id: "main",
          value: %{x: 50.0, y: 75.0, button: "right", pointer: "mouse"}
        })

      assert %WidgetEvent{type: :press, value: %{button: :right, pointer: :mouse}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes touch press with finger" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "press",
          id: "canvas1",
          window_id: "main",
          value: %{x: 50.0, y: 75.0, button: "left", pointer: "touch", finger: 0}
        })

      assert %WidgetEvent{type: :press, value: %{pointer: :touch, finger: 0}} =
               Protocol.decode_message(json, :json)
    end

    test "defaults to left button and mouse pointer when omitted" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "press",
          id: "canvas1",
          window_id: "main",
          value: %{x: 10.0, y: 20.0}
        })

      assert %WidgetEvent{type: :press, value: %{button: :left, pointer: :mouse}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "release event decoding" do
    test "decodes mouse release" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "release",
          id: "canvas1",
          window_id: "main",
          value: %{x: 100.0, y: 200.0, button: "left", pointer: "mouse"}
        })

      assert %WidgetEvent{
               type: :release,
               id: "canvas1",
               value: %{x: 100.0, y: 200.0, button: :left}
             } = Protocol.decode_message(json, :json)
    end
  end

  describe "move event decoding" do
    test "decodes pointer move" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "move",
          id: "canvas1",
          window_id: "main",
          value: %{x: 55.5, y: 88.2, pointer: "pen"}
        })

      assert %WidgetEvent{
               type: :move,
               id: "canvas1",
               value: %{x: 55.5, y: 88.2, pointer: :pen, finger: nil}
             } = Protocol.decode_message(json, :json)
    end
  end

  describe "scroll (pointer) event decoding" do
    test "decodes scroll with position and deltas" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "scroll",
          id: "canvas1",
          window_id: "main",
          value: %{
            x: 100.0,
            y: 200.0,
            delta_x: 0.0,
            delta_y: -3.0,
            pointer: "mouse",
            modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: false}
          }
        })

      assert %WidgetEvent{
               type: :scroll,
               value: %{
                 delta_y: -3.0,
                 pointer: :mouse,
                 modifiers: %Plushie.KeyModifiers{ctrl: true}
               }
             } = Protocol.decode_message(json, :json)
    end
  end

  describe "enter event decoding" do
    test "decodes pointer enter" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "enter",
          id: "hover_zone",
          window_id: "main"
        })

      assert %WidgetEvent{type: :enter, id: "hover_zone", window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "exit event decoding" do
    test "decodes pointer exit" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "exit",
          id: "hover_zone",
          window_id: "main"
        })

      assert %WidgetEvent{type: :exit, id: "hover_zone", window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "double_click event decoding" do
    test "decodes double click with position" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "double_click",
          id: "area",
          window_id: "main",
          value: %{x: 75.0, y: 150.0, pointer: "mouse"}
        })

      assert %WidgetEvent{
               type: :double_click,
               id: "area",
               value: %{x: 75.0, y: 150.0, pointer: :mouse}
             } = Protocol.decode_message(json, :json)
    end
  end

  describe "resize event decoding" do
    test "decodes resize with dimensions" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "resize",
          id: "sensor1",
          window_id: "main",
          value: %{width: 800.0, height: 600.0}
        })

      assert %WidgetEvent{
               type: :resize,
               id: "sensor1",
               window_id: "main",
               value: %{width: 800.0, height: 600.0}
             } = Protocol.decode_message(json, :json)
    end
  end
end
