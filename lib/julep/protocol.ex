defmodule Julep.Protocol do
  @moduledoc """
  Wire protocol encoding and decoding between the Elixir runtime and the iced
  renderer process.

  Messages are newline-delimited JSON. Each encode function returns a JSON
  string with a trailing newline ready to be written to the port. The decode
  function accepts a single JSON string (without the newline) and returns an
  Elixir event tuple.
  """

  # ---------------------------------------------------------------------------
  # Encoding
  # ---------------------------------------------------------------------------

  @doc """
  Encodes application-level settings as a JSON message followed by a newline.

  ## Example

      iex> Julep.Protocol.encode_settings(%{antialiasing: true, default_text_size: 16})
      ~s({"settings":{"antialiasing":true,"default_text_size":16},"type":"settings"}) <> "\\n"
  """
  @spec encode_settings(map()) :: String.t()
  def encode_settings(settings) when is_map(settings) do
    Jason.encode!(%{type: "settings", settings: settings}) <> "\n"
  end

  @doc """
  Encodes a UI tree snapshot as a JSON message followed by a newline.

  ## Example

      iex> Julep.Protocol.encode_snapshot(%{tag: "text", value: "hello"})
      ~s({"tree":{"tag":"text","value":"hello"},"type":"snapshot"}) <> "\\n"
  """
  @spec encode_snapshot(term()) :: String.t()
  def encode_snapshot(tree) do
    Jason.encode!(%{type: "snapshot", tree: tree}) <> "\n"
  end

  @doc """
  Encodes a list of patch operations as a JSON message followed by a newline.

  The ops list is encoded as-is into the JSON payload.

  ## Example

      iex> Julep.Protocol.encode_patch([])
      ~s({"ops":[],"type":"patch"}) <> "\\n"
  """
  @spec encode_patch(list()) :: String.t()
  def encode_patch(ops) do
    Jason.encode!(%{type: "patch", ops: ops}) <> "\n"
  end

  @doc """
  Encodes an effect request as a JSON message followed by a newline.

  ## Example

      iex> Julep.Protocol.encode_effect_request("req_1", "http", %{url: "https://example.com"})
      ~s({"id":"req_1","kind":"http","payload":{"url":"https://example.com"},"type":"effect_request"}) <> "\\n"
  """
  @spec encode_effect_request(String.t(), String.t(), term()) :: String.t()
  def encode_effect_request(id, kind, payload) do
    Jason.encode!(%{type: "effect_request", id: id, kind: kind, payload: payload}) <> "\n"
  end

  @doc """
  Encodes a widget operation as a JSON message followed by a newline.

  ## Example

      iex> Julep.Protocol.encode_widget_op("focus", %{target: "username"})
      ~s({"op":"focus","payload":{"target":"username"},"type":"widget_op"}) <> "\\n"
  """
  @spec encode_widget_op(String.t(), map()) :: String.t()
  def encode_widget_op(op, payload) do
    Jason.encode!(%{type: "widget_op", op: op, payload: payload}) <> "\n"
  end

  @doc """
  Encodes a subscription register message as a JSON message followed by a newline.

  ## Example

      iex> Julep.Protocol.encode_subscription_register("on_key_press", "keys")
      ~s({"kind":"on_key_press","tag":"keys","type":"subscription_register"}) <> "\\n"
  """
  @spec encode_subscription_register(String.t(), String.t()) :: String.t()
  def encode_subscription_register(kind, tag) do
    Jason.encode!(%{type: "subscription_register", kind: kind, tag: tag}) <> "\n"
  end

  @doc """
  Encodes a subscription unregister message as a JSON message followed by a newline.

  ## Example

      iex> Julep.Protocol.encode_subscription_unregister("on_key_press")
      ~s({"kind":"on_key_press","type":"subscription_unregister"}) <> "\\n"
  """
  @spec encode_subscription_unregister(String.t()) :: String.t()
  def encode_subscription_unregister(kind) do
    Jason.encode!(%{type: "subscription_unregister", kind: kind}) <> "\n"
  end

  @doc """
  Encodes a window lifecycle operation as a JSON message followed by a newline.

  ## Example

      iex> Julep.Protocol.encode_window_op("open", "main", %{title: "My App"})
      ~s({"op":"open","settings":{"title":"My App"},"type":"window_op","window_id":"main"}) <> "\\n"
  """
  @spec encode_window_op(String.t(), String.t(), map()) :: String.t()
  def encode_window_op(op, window_id, settings) do
    Jason.encode!(%{type: "window_op", op: op, window_id: window_id, settings: settings}) <> "\n"
  end

  # ---------------------------------------------------------------------------
  # Decoding
  # ---------------------------------------------------------------------------

  @doc """
  Decodes a JSON string into an event tuple.

  Returns `{:error, reason}` on parse failure or an unrecognised message shape.

  ## Examples

      iex> Julep.Protocol.decode_message(~s({"type":"event","family":"click","id":"btn_save"}))
      {:click, "btn_save"}

      iex> Julep.Protocol.decode_message("not json")
      {:error, :invalid_json}
  """
  @spec decode_message(String.t()) :: tuple() | {:error, term()}
  def decode_message(json_string) do
    case Jason.decode(json_string) do
      {:ok, msg} -> dispatch(msg)
      {:error, _} -> {:error, :invalid_json}
    end
  end

  # ---------------------------------------------------------------------------
  # Key name conversion
  # ---------------------------------------------------------------------------

  # Maps the Debug format string of iced::keyboard::key::Named variants to
  # Elixir atoms. The Rust side serializes named keys via `format!("{:?}", key)`
  # which produces the variant name as-is (e.g. "ArrowUp", "F1", "Escape").
  @named_keys %{
    # Navigation
    "Escape" => :escape,
    "Enter" => :enter,
    "Tab" => :tab,
    "Backspace" => :backspace,
    "Delete" => :delete,
    "ArrowUp" => :arrow_up,
    "ArrowDown" => :arrow_down,
    "ArrowLeft" => :arrow_left,
    "ArrowRight" => :arrow_right,
    "Home" => :home,
    "End" => :end,
    "PageUp" => :page_up,
    "PageDown" => :page_down,
    "Space" => :space,
    "Insert" => :insert,
    "Clear" => :clear,

    # Modifier keys
    "Alt" => :alt,
    "AltGraph" => :alt_graph,
    "CapsLock" => :caps_lock,
    "Control" => :control,
    "Fn" => :fn_key,
    "FnLock" => :fn_lock,
    "NumLock" => :num_lock,
    "ScrollLock" => :scroll_lock,
    "Shift" => :shift,
    "Symbol" => :symbol,
    "SymbolLock" => :symbol_lock,
    "Meta" => :meta,
    "Hyper" => :hyper,
    "Super" => :super_key,

    # Editing keys
    "Copy" => :copy,
    "Cut" => :cut,
    "Paste" => :paste,
    "Redo" => :redo,
    "Undo" => :undo,
    "CrSel" => :cr_sel,
    "EraseEof" => :erase_eof,
    "ExSel" => :ex_sel,

    # UI keys
    "Accept" => :accept,
    "Again" => :again,
    "Attn" => :attn,
    "Cancel" => :cancel,
    "ContextMenu" => :context_menu,
    "Execute" => :execute,
    "Find" => :find,
    "Help" => :help,
    "Pause" => :pause,
    "Play" => :play,
    "Props" => :props,
    "Select" => :select,
    "ZoomIn" => :zoom_in,
    "ZoomOut" => :zoom_out,

    # System keys
    "BrightnessDown" => :brightness_down,
    "BrightnessUp" => :brightness_up,
    "Eject" => :eject,
    "LogOff" => :log_off,
    "Power" => :power,
    "PowerOff" => :power_off,
    "PrintScreen" => :print_screen,
    "Hibernate" => :hibernate,
    "Standby" => :standby,
    "WakeUp" => :wake_up,

    # IME keys
    "AllCandidates" => :all_candidates,
    "Alphanumeric" => :alphanumeric,
    "CodeInput" => :code_input,
    "Compose" => :compose,
    "Convert" => :convert,
    "FinalMode" => :final_mode,
    "GroupFirst" => :group_first,
    "GroupLast" => :group_last,
    "GroupNext" => :group_next,
    "GroupPrevious" => :group_previous,
    "ModeChange" => :mode_change,
    "NextCandidate" => :next_candidate,
    "NonConvert" => :non_convert,
    "PreviousCandidate" => :previous_candidate,
    "Process" => :process,
    "SingleCandidate" => :single_candidate,

    # Korean IME
    "HangulMode" => :hangul_mode,
    "HanjaMode" => :hanja_mode,
    "JunjaMode" => :junja_mode,

    # Japanese IME
    "Eisu" => :eisu,
    "Hankaku" => :hankaku,
    "Hiragana" => :hiragana,
    "HiraganaKatakana" => :hiragana_katakana,
    "KanaMode" => :kana_mode,
    "KanjiMode" => :kanji_mode,
    "Katakana" => :katakana,
    "Romaji" => :romaji,
    "Zenkaku" => :zenkaku,
    "ZenkakuHankaku" => :zenkaku_hankaku,

    # Soft keys
    "Soft1" => :soft1,
    "Soft2" => :soft2,
    "Soft3" => :soft3,
    "Soft4" => :soft4,

    # Media keys
    "ChannelDown" => :channel_down,
    "ChannelUp" => :channel_up,
    "Close" => :close,
    "MailForward" => :mail_forward,
    "MailReply" => :mail_reply,
    "MailSend" => :mail_send,
    "MediaClose" => :media_close,
    "MediaFastForward" => :media_fast_forward,
    "MediaPause" => :media_pause,
    "MediaPlay" => :media_play,
    "MediaPlayPause" => :media_play_pause,
    "MediaRecord" => :media_record,
    "MediaRewind" => :media_rewind,
    "MediaStop" => :media_stop,
    "MediaTrackNext" => :media_track_next,
    "MediaTrackPrevious" => :media_track_previous,
    "New" => :new,
    "Open" => :open,
    "Print" => :print,
    "Save" => :save,
    "SpellCheck" => :spell_check,

    # Audio keys
    "AudioBalanceLeft" => :audio_balance_left,
    "AudioBalanceRight" => :audio_balance_right,
    "AudioBassBoostDown" => :audio_bass_boost_down,
    "AudioBassBoostToggle" => :audio_bass_boost_toggle,
    "AudioBassBoostUp" => :audio_bass_boost_up,
    "AudioFaderFront" => :audio_fader_front,
    "AudioFaderRear" => :audio_fader_rear,
    "AudioSurroundModeNext" => :audio_surround_mode_next,
    "AudioTrebleDown" => :audio_treble_down,
    "AudioTrebleUp" => :audio_treble_up,
    "AudioVolumeDown" => :audio_volume_down,
    "AudioVolumeUp" => :audio_volume_up,
    "AudioVolumeMute" => :audio_volume_mute,

    # Microphone keys
    "MicrophoneToggle" => :microphone_toggle,
    "MicrophoneVolumeDown" => :microphone_volume_down,
    "MicrophoneVolumeUp" => :microphone_volume_up,
    "MicrophoneVolumeMute" => :microphone_volume_mute,

    # Speech keys
    "SpeechCorrectionList" => :speech_correction_list,
    "SpeechInputToggle" => :speech_input_toggle,

    # Launch keys
    "LaunchApplication1" => :launch_application1,
    "LaunchApplication2" => :launch_application2,
    "LaunchCalendar" => :launch_calendar,
    "LaunchContacts" => :launch_contacts,
    "LaunchMail" => :launch_mail,
    "LaunchMediaPlayer" => :launch_media_player,
    "LaunchMusicPlayer" => :launch_music_player,
    "LaunchPhone" => :launch_phone,
    "LaunchScreenSaver" => :launch_screen_saver,
    "LaunchSpreadsheet" => :launch_spreadsheet,
    "LaunchWebBrowser" => :launch_web_browser,
    "LaunchWebCam" => :launch_web_cam,
    "LaunchWordProcessor" => :launch_word_processor,

    # Browser keys
    "BrowserBack" => :browser_back,
    "BrowserFavorites" => :browser_favorites,
    "BrowserForward" => :browser_forward,
    "BrowserHome" => :browser_home,
    "BrowserRefresh" => :browser_refresh,
    "BrowserSearch" => :browser_search,
    "BrowserStop" => :browser_stop,

    # Mobile / phone keys
    "AppSwitch" => :app_switch,
    "Call" => :call,
    "Camera" => :camera,
    "CameraFocus" => :camera_focus,
    "EndCall" => :end_call,
    "GoBack" => :go_back,
    "GoHome" => :go_home,
    "HeadsetHook" => :headset_hook,
    "LastNumberRedial" => :last_number_redial,
    "Notification" => :notification,
    "MannerMode" => :manner_mode,
    "VoiceDial" => :voice_dial,

    # TV keys
    "TV" => :tv,
    "TV3DMode" => :tv_3d_mode,
    "TVAntennaCable" => :tv_antenna_cable,
    "TVAudioDescription" => :tv_audio_description,
    "TVAudioDescriptionMixDown" => :tv_audio_description_mix_down,
    "TVAudioDescriptionMixUp" => :tv_audio_description_mix_up,
    "TVContentsMenu" => :tv_contents_menu,
    "TVDataService" => :tv_data_service,
    "TVInput" => :tv_input,
    "TVInputComponent1" => :tv_input_component1,
    "TVInputComponent2" => :tv_input_component2,
    "TVInputComposite1" => :tv_input_composite1,
    "TVInputComposite2" => :tv_input_composite2,
    "TVInputHDMI1" => :tv_input_hdmi1,
    "TVInputHDMI2" => :tv_input_hdmi2,
    "TVInputHDMI3" => :tv_input_hdmi3,
    "TVInputHDMI4" => :tv_input_hdmi4,
    "TVInputVGA1" => :tv_input_vga1,
    "TVMediaContext" => :tv_media_context,
    "TVNetwork" => :tv_network,
    "TVNumberEntry" => :tv_number_entry,
    "TVPower" => :tv_power,
    "TVRadioService" => :tv_radio_service,
    "TVSatellite" => :tv_satellite,
    "TVSatelliteBS" => :tv_satellite_bs,
    "TVSatelliteCS" => :tv_satellite_cs,
    "TVSatelliteToggle" => :tv_satellite_toggle,
    "TVTerrestrialAnalog" => :tv_terrestrial_analog,
    "TVTerrestrialDigital" => :tv_terrestrial_digital,
    "TVTimer" => :tv_timer,

    # Numpad keys
    "Key11" => :key11,
    "Key12" => :key12,
    "NumpadBackspace" => :numpad_backspace,
    "NumpadClear" => :numpad_clear,
    "NumpadClearEntry" => :numpad_clear_entry,
    "NumpadComma" => :numpad_comma,
    "NumpadDecimal" => :numpad_decimal,
    "NumpadDivide" => :numpad_divide,
    "NumpadEnter" => :numpad_enter,
    "NumpadEqual" => :numpad_equal,
    "NumpadHash" => :numpad_hash,
    "NumpadMemoryAdd" => :numpad_memory_add,
    "NumpadMemoryClear" => :numpad_memory_clear,
    "NumpadMemoryRecall" => :numpad_memory_recall,
    "NumpadMemoryStore" => :numpad_memory_store,
    "NumpadMemorySubtract" => :numpad_memory_subtract,
    "NumpadMultiply" => :numpad_multiply,
    "NumpadParenLeft" => :numpad_paren_left,
    "NumpadParenRight" => :numpad_paren_right,
    "NumpadStar" => :numpad_star,
    "NumpadSubtract" => :numpad_subtract,

    # Function keys F1-F35
    "F1" => :f1,
    "F2" => :f2,
    "F3" => :f3,
    "F4" => :f4,
    "F5" => :f5,
    "F6" => :f6,
    "F7" => :f7,
    "F8" => :f8,
    "F9" => :f9,
    "F10" => :f10,
    "F11" => :f11,
    "F12" => :f12,
    "F13" => :f13,
    "F14" => :f14,
    "F15" => :f15,
    "F16" => :f16,
    "F17" => :f17,
    "F18" => :f18,
    "F19" => :f19,
    "F20" => :f20,
    "F21" => :f21,
    "F22" => :f22,
    "F23" => :f23,
    "F24" => :f24,
    "F25" => :f25,
    "F26" => :f26,
    "F27" => :f27,
    "F28" => :f28,
    "F29" => :f29,
    "F30" => :f30,
    "F31" => :f31,
    "F32" => :f32,
    "F33" => :f33,
    "F34" => :f34,
    "F35" => :f35,

    # Unidentified
    "Unidentified" => :unidentified
  }

  @doc """
  Converts a key name string to an atom for named keys, or returns the string
  unchanged for single-character keys.

  ## Examples

      iex> Julep.Protocol.parse_key("Escape")
      :escape

      iex> Julep.Protocol.parse_key("a")
      "a"
  """
  @spec parse_key(String.t()) :: atom() | String.t()
  def parse_key(key) when is_binary(key) do
    Map.get(@named_keys, key, key)
  end

  # ---------------------------------------------------------------------------
  # Modifier parsing helper
  # ---------------------------------------------------------------------------

  defp parse_modifiers(mods) when is_map(mods) do
    %{
      ctrl: Map.get(mods, "ctrl", false),
      shift: Map.get(mods, "shift", false),
      alt: Map.get(mods, "alt", false),
      logo: Map.get(mods, "logo", false),
      command: Map.get(mods, "command", false)
    }
  end

  defp parse_modifiers(_),
    do: %{ctrl: false, shift: false, alt: false, logo: false, command: false}

  # ---------------------------------------------------------------------------
  # Private dispatch
  # ---------------------------------------------------------------------------

  # -- Widget events --

  defp dispatch(%{"type" => "event", "family" => "click", "id" => id}) do
    {:click, id}
  end

  defp dispatch(%{"type" => "event", "family" => "input", "id" => id, "value" => value}) do
    {:input, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "submit", "id" => id, "value" => value}) do
    {:submit, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "toggle", "id" => id, "value" => value}) do
    {:toggle, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "select", "id" => id, "value" => value}) do
    {:select, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "slide", "id" => id, "value" => value}) do
    {:slide, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "slide_release", "id" => id, "value" => value}) do
    {:slide_release, id, value}
  end

  # -- Keyboard events --
  # Rust emits family "key_press" with the key in "value" and modifiers in "modifiers".

  defp dispatch(%{
         "type" => "event",
         "family" => "key_press",
         "value" => key,
         "modifiers" => mods
       }) do
    {:key_press, parse_key(key), parse_modifiers(mods)}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "key_release",
         "value" => key,
         "modifiers" => mods
       }) do
    {:key_release, parse_key(key), parse_modifiers(mods)}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "modifiers_changed",
         "modifiers" => mods
       }) do
    {:modifiers_changed, parse_modifiers(mods)}
  end

  # -- Mouse events --

  defp dispatch(%{"type" => "event", "family" => "cursor_moved", "x" => x, "y" => y}) do
    {:cursor_moved, x, y}
  end

  defp dispatch(%{"type" => "event", "family" => "cursor_entered"}) do
    {:cursor_entered}
  end

  defp dispatch(%{"type" => "event", "family" => "cursor_left"}) do
    {:cursor_left}
  end

  defp dispatch(%{"type" => "event", "family" => "button_pressed", "value" => button}) do
    {:button_pressed, button}
  end

  defp dispatch(%{"type" => "event", "family" => "button_released", "value" => button}) do
    {:button_released, button}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "wheel_scrolled",
         "delta_x" => dx,
         "delta_y" => dy,
         "unit" => unit
       }) do
    {:wheel_scrolled, dx, dy, unit}
  end

  # -- Touch events --

  defp dispatch(%{
         "type" => "event",
         "family" => "finger_pressed",
         "finger_id" => finger_id,
         "x" => x,
         "y" => y
       }) do
    {:finger_pressed, finger_id, x, y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "finger_moved",
         "finger_id" => finger_id,
         "x" => x,
         "y" => y
       }) do
    {:finger_moved, finger_id, x, y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "finger_lifted",
         "finger_id" => finger_id,
         "x" => x,
         "y" => y
       }) do
    {:finger_lifted, finger_id, x, y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "finger_lost",
         "finger_id" => finger_id,
         "x" => x,
         "y" => y
       }) do
    {:finger_lost, finger_id, x, y}
  end

  # -- Window lifecycle events --

  defp dispatch(%{
         "type" => "event",
         "family" => "window_opened",
         "window_id" => window_id,
         "position" => position,
         "width" => width,
         "height" => height
       }) do
    pos =
      case position do
        %{"x" => x, "y" => y} -> {x, y}
        _ -> nil
      end

    {:window_opened, window_id, pos, {width, height}}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_closed",
         "window_id" => window_id
       }) do
    {:window_closed, window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_close_requested",
         "window_id" => window_id
       }) do
    {:window_close_requested, window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_moved",
         "window_id" => window_id,
         "x" => x,
         "y" => y
       }) do
    {:window_moved, window_id, x, y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_resized",
         "window_id" => window_id,
         "width" => width,
         "height" => height
       }) do
    {:window_resized, window_id, width, height}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_focused",
         "window_id" => window_id
       }) do
    {:window_focused, window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_unfocused",
         "window_id" => window_id
       }) do
    {:window_unfocused, window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_rescaled",
         "window_id" => window_id,
         "scale_factor" => scale_factor
       }) do
    {:window_rescaled, window_id, scale_factor}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "file_hovered",
         "window_id" => window_id,
         "path" => path
       }) do
    {:file_hovered, window_id, path}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "file_dropped",
         "window_id" => window_id,
         "path" => path
       }) do
    {:file_dropped, window_id, path}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "files_hovered_left",
         "window_id" => window_id
       }) do
    {:files_hovered_left, window_id}
  end

  # -- Animation / theme / system events --

  defp dispatch(%{
         "type" => "event",
         "family" => "animation_frame",
         "timestamp" => timestamp
       }) do
    {:animation_frame, timestamp}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "theme_changed",
         "value" => mode
       }) do
    {:theme_changed, mode}
  end

  # -- Legacy window event format (kept for backwards compatibility) --

  defp dispatch(%{
         "type" => "event",
         "family" => "window",
         "action" => action,
         "window_id" => window_id
       }) do
    {:window, String.to_atom(action), window_id}
  end

  # -- Canvas events --

  defp dispatch(%{"type" => "event", "family" => "canvas_press", "id" => id, "data" => data}) do
    button = Map.get(data, "button", "left")
    {:canvas_press, id, data["x"], data["y"], button}
  end

  defp dispatch(%{"type" => "event", "family" => "canvas_release", "id" => id, "data" => data}) do
    button = Map.get(data, "button", "left")
    {:canvas_release, id, data["x"], data["y"], button}
  end

  defp dispatch(%{"type" => "event", "family" => "canvas_move", "id" => id, "data" => data}) do
    {:canvas_move, id, data["x"], data["y"]}
  end

  defp dispatch(%{"type" => "event", "family" => "canvas_scroll", "id" => id, "data" => data}) do
    {:canvas_scroll, id, data["x"], data["y"], data["delta_x"], data["delta_y"]}
  end

  # -- Sensor events --

  defp dispatch(%{"type" => "event", "family" => "sensor_resize", "id" => id, "data" => data}) do
    {:sensor_resize, id, data["width"], data["height"]}
  end

  # -- PaneGrid events --

  defp dispatch(%{"type" => "event", "family" => "pane_resized", "id" => id, "data" => data}) do
    {:pane_resized, id, data["split"], data["ratio"]}
  end

  defp dispatch(%{"type" => "event", "family" => "pane_dragged", "id" => id, "data" => data}) do
    {:pane_dragged, id, data["pane"], data["target"]}
  end

  defp dispatch(%{"type" => "event", "family" => "pane_clicked", "id" => id, "data" => data}) do
    {:pane_clicked, id, data["pane"]}
  end

  # -- Effect responses --

  defp dispatch(%{
         "type" => "effect_response",
         "id" => id,
         "status" => "ok",
         "result" => result
       }) do
    {:effect_result, id, {:ok, result}}
  end

  defp dispatch(%{
         "type" => "effect_response",
         "id" => id,
         "status" => "error",
         "error" => reason
       }) do
    {:effect_result, id, {:error, reason}}
  end

  defp dispatch(msg) do
    {:error, {:unknown_message, msg}}
  end
end
