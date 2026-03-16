defmodule Julep.ProtocolParityTest do
  @moduledoc """
  Tests for all new protocol event decoders added in the iced parity pass.
  Does not duplicate tests from protocol_test.exs -- only covers new events.
  """
  use ExUnit.Case, async: true

  alias Julep.Protocol

  # ---------------------------------------------------------------------------
  # Key events (new format: family "key_press"/"key_release" with "value" field)
  # ---------------------------------------------------------------------------

  describe "key_press event decoding" do
    test "decodes named key with modifiers" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          value: "Escape",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false}
        })

      assert {:key_press,
              %Julep.KeyEvent{key: :escape, modifiers: %Julep.KeyModifiers{ctrl: false}}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes character key" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          value: "a",
          modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: false}
        })

      assert {:key_press, %Julep.KeyEvent{key: "a", modifiers: %Julep.KeyModifiers{ctrl: true}}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes with ctrl+shift modifiers" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          value: "Tab",
          modifiers: %{ctrl: true, shift: true, alt: false, logo: false, command: false}
        })

      assert {:key_press,
              %Julep.KeyEvent{
                key: :tab,
                modifiers: %Julep.KeyModifiers{ctrl: true, shift: true}
              }} = Protocol.decode_message(json, :json)
    end
  end

  describe "key_release event decoding" do
    test "decodes named key release" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_release",
          value: "Control",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false}
        })

      assert {:key_release, %Julep.KeyEvent{key: :control}} = Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # Named key mapping (representative sample)
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Mouse events
  # ---------------------------------------------------------------------------

  describe "cursor_moved event" do
    test "decodes cursor position" do
      json = Jason.encode!(%{type: "event", family: "cursor_moved", data: %{x: 100.5, y: 200.3}})
      assert {:cursor_moved, %{x: 100.5, y: 200.3, captured: false}} = Protocol.decode_message(json, :json)
    end

    test "decodes integer coordinates" do
      json = Jason.encode!(%{type: "event", family: "cursor_moved", data: %{x: 0, y: 0}})
      assert {:cursor_moved, %{x: 0, y: 0, captured: false}} = Protocol.decode_message(json, :json)
    end
  end

  describe "cursor_entered event" do
    test "decodes cursor entered" do
      json = Jason.encode!(%{type: "event", family: "cursor_entered"})
      assert {:cursor_entered, %{captured: false}} = Protocol.decode_message(json, :json)
    end
  end

  describe "cursor_left event" do
    test "decodes cursor left" do
      json = Jason.encode!(%{type: "event", family: "cursor_left"})
      assert {:cursor_left, %{captured: false}} = Protocol.decode_message(json, :json)
    end
  end

  describe "button_pressed event" do
    test "decodes mouse button press" do
      json = Jason.encode!(%{type: "event", family: "button_pressed", value: "left"})
      assert {:button_pressed, %{button: "left", captured: false}} = Protocol.decode_message(json, :json)
    end

    test "decodes right button press" do
      json = Jason.encode!(%{type: "event", family: "button_pressed", value: "right"})
      assert {:button_pressed, %{button: "right", captured: false}} = Protocol.decode_message(json, :json)
    end
  end

  describe "button_released event" do
    test "decodes mouse button release" do
      json = Jason.encode!(%{type: "event", family: "button_released", value: "left"})
      assert {:button_released, %{button: "left", captured: false}} = Protocol.decode_message(json, :json)
    end
  end

  describe "wheel_scrolled event" do
    test "decodes scroll with delta and unit" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "wheel_scrolled",
          data: %{delta_x: 0.0, delta_y: -3.0, unit: "line"}
        })

      assert {:wheel_scrolled, %{delta_x: 0.0, delta_y: -3.0, unit: "line", captured: false}} = Protocol.decode_message(json, :json)
    end

    test "decodes pixel scroll unit" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "wheel_scrolled",
          data: %{delta_x: 10.0, delta_y: 20.0, unit: "pixel"}
        })

      assert {:wheel_scrolled, %{delta_x: 10.0, delta_y: 20.0, unit: "pixel", captured: false}} = Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # Touch events
  # ---------------------------------------------------------------------------

  describe "finger_pressed event" do
    test "decodes finger press with id and position" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_pressed",
          data: %{finger_id: 0, x: 50.0, y: 75.0}
        })

      assert {:finger_pressed, %{finger_id: 0, x: 50.0, y: 75.0, captured: false}} = Protocol.decode_message(json, :json)
    end
  end

  describe "finger_moved event" do
    test "decodes finger move" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_moved",
          data: %{finger_id: 1, x: 60.0, y: 80.0}
        })

      assert {:finger_moved, %{finger_id: 1, x: 60.0, y: 80.0, captured: false}} = Protocol.decode_message(json, :json)
    end
  end

  describe "finger_lifted event" do
    test "decodes finger lift" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_lifted",
          data: %{finger_id: 0, x: 55.0, y: 70.0}
        })

      assert {:finger_lifted, %{finger_id: 0, x: 55.0, y: 70.0, captured: false}} = Protocol.decode_message(json, :json)
    end
  end

  describe "finger_lost event" do
    test "decodes finger lost" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_lost",
          data: %{finger_id: 2, x: 30.0, y: 40.0}
        })

      assert {:finger_lost, %{finger_id: 2, x: 30.0, y: 40.0, captured: false}} = Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # Window lifecycle events
  # ---------------------------------------------------------------------------

  describe "window_opened event" do
    test "decodes window opened with position and size" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_opened",
          data: %{window_id: "main", position: %{x: 100, y: 200}, width: 800, height: 600}
        })

      assert {:window_opened, "main", {100, 200}, {800, 600}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes window opened with nil position" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_opened",
          data: %{window_id: "main", position: nil, width: 1024, height: 768}
        })

      assert {:window_opened, "main", nil, {1024, 768}} = Protocol.decode_message(json, :json)
    end
  end

  describe "window_closed event" do
    test "decodes window closed" do
      json =
        Jason.encode!(%{type: "event", family: "window_closed", data: %{window_id: "settings"}})

      assert {:window_closed, "settings"} = Protocol.decode_message(json, :json)
    end
  end

  describe "window_moved event" do
    test "decodes window moved with coordinates" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_moved",
          data: %{window_id: "main", x: 300, y: 150}
        })

      assert {:window_moved, "main", 300, 150} = Protocol.decode_message(json, :json)
    end
  end

  describe "window_resized event" do
    test "decodes window resized with dimensions" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_resized",
          data: %{window_id: "main", width: 1920, height: 1080}
        })

      assert {:window_resized, "main", 1920, 1080} = Protocol.decode_message(json, :json)
    end
  end

  describe "window_focused event" do
    test "decodes window focused" do
      json = Jason.encode!(%{type: "event", family: "window_focused", data: %{window_id: "main"}})
      assert {:window_focused, "main"} = Protocol.decode_message(json, :json)
    end
  end

  describe "window_unfocused event" do
    test "decodes window unfocused" do
      json =
        Jason.encode!(%{type: "event", family: "window_unfocused", data: %{window_id: "main"}})

      assert {:window_unfocused, "main"} = Protocol.decode_message(json, :json)
    end
  end

  describe "window_rescaled event" do
    test "decodes window rescaled with scale factor" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_rescaled",
          data: %{window_id: "main", scale_factor: 2.0}
        })

      assert {:window_rescaled, "main", 2.0} = Protocol.decode_message(json, :json)
    end
  end

  describe "window_close_requested event" do
    test "decodes window close request" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window_close_requested",
          data: %{window_id: "main"}
        })

      assert {:window_close_requested, "main"} = Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # File events
  # ---------------------------------------------------------------------------

  describe "file_hovered event" do
    test "decodes file hovered over window" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "file_hovered",
          data: %{window_id: "main", path: "/tmp/test.txt"}
        })

      assert {:file_hovered, "main", "/tmp/test.txt"} = Protocol.decode_message(json, :json)
    end
  end

  describe "file_dropped event" do
    test "decodes file dropped on window" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "file_dropped",
          data: %{window_id: "main", path: "/tmp/image.png"}
        })

      assert {:file_dropped, "main", "/tmp/image.png"} = Protocol.decode_message(json, :json)
    end
  end

  describe "files_hovered_left event" do
    test "decodes files hovered left" do
      json =
        Jason.encode!(%{type: "event", family: "files_hovered_left", data: %{window_id: "main"}})

      assert {:files_hovered_left, "main"} = Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # Modifiers / animation / theme events
  # ---------------------------------------------------------------------------

  describe "modifiers_changed event" do
    test "decodes modifier state change" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "modifiers_changed",
          modifiers: %{ctrl: true, shift: false, alt: true, logo: false, command: false}
        })

      assert {:modifiers_changed, %{ctrl: true, alt: true, shift: false}} =
               Protocol.decode_message(json, :json)
    end

    test "handles missing modifier fields with defaults" do
      json = Jason.encode!(%{type: "event", family: "modifiers_changed", modifiers: %{}})

      assert {:modifiers_changed,
              %{ctrl: false, shift: false, alt: false, logo: false, command: false}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "animation_frame event" do
    test "decodes animation frame with timestamp" do
      json =
        Jason.encode!(%{type: "event", family: "animation_frame", data: %{timestamp: 16_666}})

      assert {:animation_frame, 16_666} = Protocol.decode_message(json, :json)
    end

    test "decodes float timestamp" do
      json =
        Jason.encode!(%{type: "event", family: "animation_frame", data: %{timestamp: 16.666}})

      assert {:animation_frame, 16.666} = Protocol.decode_message(json, :json)
    end
  end

  describe "theme_changed event" do
    test "decodes theme change to dark" do
      json = Jason.encode!(%{type: "event", family: "theme_changed", value: "dark"})
      assert {:theme_changed, "dark"} = Protocol.decode_message(json, :json)
    end

    test "decodes theme change to light" do
      json = Jason.encode!(%{type: "event", family: "theme_changed", value: "light"})
      assert {:theme_changed, "light"} = Protocol.decode_message(json, :json)
    end
  end
end
