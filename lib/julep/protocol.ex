defmodule Julep.Protocol do
  @moduledoc """
  Wire protocol encoding and decoding between the Elixir runtime and the iced
  renderer process.

  Supports two wire formats:

  * `:json` -- newline-delimited JSON. Opt-in for debugging and observability.
    Each encode function returns a JSON string with a trailing newline.
  * `:msgpack` -- MessagePack via `Msgpax` (default). Returns raw binary with no
    length prefix (Erlang's `{:packet, 4}` Port driver handles framing).

  The decode function accepts a binary in either format and returns an
  Elixir event tuple.
  """

  @typedoc "Wire format for protocol messages."
  @type format :: :json | :msgpack

  # ---------------------------------------------------------------------------
  # Serialization helpers
  # ---------------------------------------------------------------------------

  @doc """
  Encodes an arbitrary map as a wire-format binary.

  For `:json`, returns a JSON string with a trailing newline.
  For `:msgpack`, returns raw msgpack bytes (no length prefix -- the Erlang
  `{:packet, 4}` Port driver handles framing).
  """
  @spec encode(message :: map(), format :: format()) :: binary()
  def encode(map, format \\ :msgpack), do: serialize(map, format)

  @doc """
  Decodes a wire-format binary into a string-keyed map without dispatch.

  Unlike `decode_message/2` which dispatches into Elixir event tuples, this
  returns the raw deserialized map. Used by test backends that handle
  renderer responses (query_response, interact_response, etc.) directly.
  """
  @spec decode(data :: binary(), format :: format()) :: {:ok, map()} | {:error, term()}
  def decode(data, format \\ :msgpack), do: deserialize(data, format)

  defp serialize(map, :json), do: Jason.encode!(map) <> "\n"
  defp serialize(map, :msgpack), do: Msgpax.pack!(map, iodata: false)

  defp deserialize(data, :json), do: Jason.decode(data)
  defp deserialize(data, :msgpack), do: Msgpax.unpack(data)

  # ---------------------------------------------------------------------------
  # Encoding
  # ---------------------------------------------------------------------------

  @doc """
  Encodes application-level settings as a protocol message.

  ## Example

      iex> Julep.Protocol.encode_settings(%{antialiasing: true, default_text_size: 16}, :json)
      ~s({"settings":{"antialiasing":true,"default_text_size":16},"type":"settings"}) <> "\\n"
  """
  @spec encode_settings(settings :: map(), format :: format()) :: binary()
  def encode_settings(settings, format \\ :msgpack) when is_map(settings) do
    serialize(%{type: "settings", settings: settings}, format)
  end

  @doc """
  Encodes a UI tree snapshot as a protocol message.

  ## Example

      iex> Julep.Protocol.encode_snapshot(%{tag: "text", value: "hello"}, :json)
      ~s({"tree":{"tag":"text","value":"hello"},"type":"snapshot"}) <> "\\n"
  """
  @spec encode_snapshot(tree :: term(), format :: format()) :: binary()
  def encode_snapshot(tree, format \\ :msgpack) do
    serialize(%{type: "snapshot", tree: tree}, format)
  end

  @doc """
  Encodes a list of patch operations as a protocol message.

  The ops list is encoded as-is into the payload.

  ## Example

      iex> Julep.Protocol.encode_patch([], :json)
      ~s({"ops":[],"type":"patch"}) <> "\\n"
  """
  @spec encode_patch(ops :: list(), format :: format()) :: binary()
  def encode_patch(ops, format \\ :msgpack) do
    serialize(%{type: "patch", ops: ops}, format)
  end

  @doc """
  Encodes an effect request as a protocol message.

  ## Example

      iex> Julep.Protocol.encode_effect_request("req_1", "http", %{url: "https://example.com"})
      ~s({"id":"req_1","kind":"http","payload":{"url":"https://example.com"},"type":"effect_request"}) <> "\\n"
  """
  @spec encode_effect_request(
          id :: String.t(),
          kind :: String.t(),
          payload :: term(),
          format :: format()
        ) :: binary()
  def encode_effect_request(id, kind, payload, format \\ :msgpack) do
    serialize(%{type: "effect_request", id: id, kind: kind, payload: payload}, format)
  end

  @doc """
  Encodes a widget operation as a protocol message.

  ## Example

      iex> Julep.Protocol.encode_widget_op("focus", %{target: "username"})
      ~s({"op":"focus","payload":{"target":"username"},"type":"widget_op"}) <> "\\n"
  """
  @spec encode_widget_op(op :: String.t(), payload :: map(), format :: format()) :: binary()
  def encode_widget_op(op, payload, format \\ :msgpack) do
    serialize(%{type: "widget_op", op: op, payload: payload}, format)
  end

  @doc """
  Encodes a subscription register message as a protocol message.

  ## Example

      iex> Julep.Protocol.encode_subscription_register("on_key_press", "keys")
      ~s({"kind":"on_key_press","tag":"keys","type":"subscription_register"}) <> "\\n"
  """
  @spec encode_subscription_register(kind :: String.t(), tag :: String.t(), format :: format()) ::
          binary()
  def encode_subscription_register(kind, tag, format \\ :msgpack) do
    serialize(%{type: "subscription_register", kind: kind, tag: tag}, format)
  end

  @doc """
  Encodes a subscription unregister message as a protocol message.

  ## Example

      iex> Julep.Protocol.encode_subscription_unregister("on_key_press")
      ~s({"kind":"on_key_press","type":"subscription_unregister"}) <> "\\n"
  """
  @spec encode_subscription_unregister(kind :: String.t(), format :: format()) :: binary()
  def encode_subscription_unregister(kind, format \\ :msgpack) do
    serialize(%{type: "subscription_unregister", kind: kind}, format)
  end

  @doc """
  Encodes an image operation as a protocol message.

  Image ops are `create_image`, `update_image`, or `delete_image`. The payload
  map contains the op-specific fields (handle, data/pixels, width, height).

  Binary fields (`data`, `pixels`) are encoded based on the wire format:
  - `:msgpack` -- wrapped in `Msgpax.Bin` for native msgpack binary type (zero overhead)
  - `:json` -- base64-encoded strings (JSON has no binary type)

  ## Example

      iex> Julep.Protocol.encode_image_op("create_image", %{handle: "logo", data: <<1, 2, 3>>}, :json)
      ~s({"data":"AQID","handle":"logo","op":"create_image","type":"image_op"}) <> "\\n"
  """
  @spec encode_image_op(op :: String.t(), payload :: map(), format :: format()) :: binary()
  def encode_image_op(op, payload, format \\ :msgpack) do
    payload = encode_binary_fields(payload, format)
    serialize(Map.merge(%{type: "image_op", op: op}, payload), format)
  end

  # Encode binary fields in image op payloads based on wire format.
  defp encode_binary_fields(payload, :msgpack) do
    payload
    |> maybe_wrap_binary(:data)
    |> maybe_wrap_binary(:pixels)
  end

  defp encode_binary_fields(payload, :json) do
    payload
    |> maybe_base64_encode(:data)
    |> maybe_base64_encode(:pixels)
  end

  defp maybe_wrap_binary(payload, key) do
    case Map.get(payload, key) do
      nil -> payload
      bin when is_binary(bin) -> Map.put(payload, key, Msgpax.Bin.new(bin))
      _other -> payload
    end
  end

  defp maybe_base64_encode(payload, key) do
    case Map.get(payload, key) do
      nil -> payload
      bin when is_binary(bin) -> Map.put(payload, key, Base.encode64(bin))
      _other -> payload
    end
  end

  @doc """
  Encodes a window lifecycle operation as a protocol message.

  ## Example

      iex> Julep.Protocol.encode_window_op("open", "main", %{title: "My App"})
      ~s({"op":"open","settings":{"title":"My App"},"type":"window_op","window_id":"main"}) <> "\\n"
  """
  @spec encode_window_op(
          op :: String.t(),
          window_id :: String.t(),
          settings :: map(),
          format :: format()
        ) :: binary()
  def encode_window_op(op, window_id, settings, format \\ :msgpack) do
    serialize(%{type: "window_op", op: op, window_id: window_id, settings: settings}, format)
  end

  # ---------------------------------------------------------------------------
  # Decoding
  # ---------------------------------------------------------------------------

  @doc """
  Decodes a protocol message into an event tuple.

  Returns `{:error, reason}` on parse failure or an unrecognised message shape.

  ## Examples

      iex> Julep.Protocol.decode_message(~s({"type":"event","family":"click","id":"btn_save"}))
      {:click, "btn_save"}

      iex> Julep.Protocol.decode_message("not json")
      {:error, :decode_failed}
  """
  @spec decode_message(data :: binary(), format :: format()) :: tuple() | {:error, term()}
  def decode_message(data, format \\ :msgpack) do
    case deserialize(data, format) do
      {:ok, msg} -> dispatch(msg)
      {:error, _} -> {:error, :decode_failed}
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

  # Physical key codes -- Rust KeyCode Debug format -> Elixir atoms.
  # Covers all standard US keyboard physical keys. Unknown codes pass through
  # as strings.
  @physical_keys %{
    # Letters
    "KeyA" => :key_a,
    "KeyB" => :key_b,
    "KeyC" => :key_c,
    "KeyD" => :key_d,
    "KeyE" => :key_e,
    "KeyF" => :key_f,
    "KeyG" => :key_g,
    "KeyH" => :key_h,
    "KeyI" => :key_i,
    "KeyJ" => :key_j,
    "KeyK" => :key_k,
    "KeyL" => :key_l,
    "KeyM" => :key_m,
    "KeyN" => :key_n,
    "KeyO" => :key_o,
    "KeyP" => :key_p,
    "KeyQ" => :key_q,
    "KeyR" => :key_r,
    "KeyS" => :key_s,
    "KeyT" => :key_t,
    "KeyU" => :key_u,
    "KeyV" => :key_v,
    "KeyW" => :key_w,
    "KeyX" => :key_x,
    "KeyY" => :key_y,
    "KeyZ" => :key_z,
    # Digits
    "Digit0" => :digit_0,
    "Digit1" => :digit_1,
    "Digit2" => :digit_2,
    "Digit3" => :digit_3,
    "Digit4" => :digit_4,
    "Digit5" => :digit_5,
    "Digit6" => :digit_6,
    "Digit7" => :digit_7,
    "Digit8" => :digit_8,
    "Digit9" => :digit_9,
    # Function keys
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
    # Modifiers
    "ShiftLeft" => :shift_left,
    "ShiftRight" => :shift_right,
    "ControlLeft" => :control_left,
    "ControlRight" => :control_right,
    "AltLeft" => :alt_left,
    "AltRight" => :alt_right,
    "MetaLeft" => :meta_left,
    "MetaRight" => :meta_right,
    # Navigation
    "Escape" => :escape,
    "Enter" => :enter,
    "Tab" => :tab,
    "Backspace" => :backspace,
    "Delete" => :delete,
    "Insert" => :insert,
    "Home" => :home,
    "End" => :end,
    "PageUp" => :page_up,
    "PageDown" => :page_down,
    "ArrowUp" => :arrow_up,
    "ArrowDown" => :arrow_down,
    "ArrowLeft" => :arrow_left,
    "ArrowRight" => :arrow_right,
    "Space" => :space,
    "CapsLock" => :caps_lock,
    # Punctuation / symbols
    "Minus" => :minus,
    "Equal" => :equal,
    "BracketLeft" => :bracket_left,
    "BracketRight" => :bracket_right,
    "Backslash" => :backslash,
    "Semicolon" => :semicolon,
    "Quote" => :quote,
    "Backquote" => :backquote,
    "Comma" => :comma,
    "Period" => :period,
    "Slash" => :slash,
    # Numpad
    "Numpad0" => :numpad_0,
    "Numpad1" => :numpad_1,
    "Numpad2" => :numpad_2,
    "Numpad3" => :numpad_3,
    "Numpad4" => :numpad_4,
    "Numpad5" => :numpad_5,
    "Numpad6" => :numpad_6,
    "Numpad7" => :numpad_7,
    "Numpad8" => :numpad_8,
    "Numpad9" => :numpad_9,
    "NumpadAdd" => :numpad_add,
    "NumpadSubtract" => :numpad_subtract,
    "NumpadMultiply" => :numpad_multiply,
    "NumpadDivide" => :numpad_divide,
    "NumpadDecimal" => :numpad_decimal,
    "NumpadEnter" => :numpad_enter,
    "NumLock" => :num_lock,
    "ScrollLock" => :scroll_lock,
    "PrintScreen" => :print_screen,
    "Pause" => :pause,
    "ContextMenu" => :context_menu
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
  @spec parse_key(key :: String.t()) :: atom() | String.t()
  def parse_key(key) when is_binary(key) do
    Map.get(@named_keys, key, key)
  end

  # ---------------------------------------------------------------------------
  # Modifier parsing helper
  # ---------------------------------------------------------------------------

  defp parse_modifiers(mods) when is_map(mods) do
    %Julep.KeyModifiers{
      ctrl: Map.get(mods, "ctrl", false),
      shift: Map.get(mods, "shift", false),
      alt: Map.get(mods, "alt", false),
      logo: Map.get(mods, "logo", false),
      command: Map.get(mods, "command", false)
    }
  end

  defp parse_modifiers(_), do: %Julep.KeyModifiers{}

  defp parse_physical_key(nil), do: nil

  defp parse_physical_key(str) when is_binary(str) do
    Map.get(@physical_keys, str, str)
  end

  defp parse_location("left"), do: :left
  defp parse_location("right"), do: :right
  defp parse_location("numpad"), do: :numpad
  defp parse_location(_), do: :standard

  # ---------------------------------------------------------------------------
  # Private dispatch
  # ---------------------------------------------------------------------------

  # -- Outgoing message types (for roundtrip testing and diagnostics) --

  defp dispatch(%{"type" => "settings", "settings" => settings}) do
    {:settings, settings}
  end

  defp dispatch(%{"type" => "snapshot", "tree" => tree}) do
    {:snapshot, tree}
  end

  defp dispatch(%{"type" => "patch", "ops" => ops}) do
    {:patch, ops}
  end

  defp dispatch(%{
         "type" => "effect_request",
         "id" => id,
         "kind" => kind,
         "payload" => payload
       }) do
    {:effect_request, id, kind, payload}
  end

  defp dispatch(%{"type" => "widget_op", "op" => op, "payload" => payload}) do
    {:widget_op, op, payload}
  end

  defp dispatch(%{"type" => "subscription_register", "kind" => kind, "tag" => tag}) do
    {:subscription_register, kind, tag}
  end

  defp dispatch(%{"type" => "subscription_unregister", "kind" => kind}) do
    {:subscription_unregister, kind}
  end

  defp dispatch(%{
         "type" => "window_op",
         "op" => op,
         "window_id" => window_id,
         "settings" => settings
       }) do
    {:window_op, op, window_id, settings}
  end

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

  defp dispatch(%{"type" => "event", "family" => "paste", "id" => id, "value" => text}) do
    {:paste, id, text}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "option_hovered",
         "id" => id,
         "value" => value
       }) do
    {:option_hovered, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "open", "id" => id}),
    do: {:open, id}

  defp dispatch(%{"type" => "event", "family" => "close", "id" => id}),
    do: {:close, id}

  defp dispatch(%{"type" => "event", "family" => "key_binding", "id" => id, "data" => data}),
    do: {:key_binding, id, data}

  # -- Keyboard events --
  # Rust emits family "key_press" with the key in "value", modifiers in "modifiers",
  # and extra fields (modified_key, physical_key, location, text, repeat) in "data".

  defp dispatch(
         %{
           "type" => "event",
           "family" => "key_press",
           "value" => key,
           "modifiers" => mods
         } = msg
       ) do
    data = msg["data"] || %{}

    {:key_press,
     %Julep.KeyEvent{
       key: parse_key(key),
       modified_key: parse_key(data["modified_key"] || key),
       physical_key: parse_physical_key(data["physical_key"]),
       location: parse_location(data["location"]),
       modifiers: parse_modifiers(mods),
       text: data["text"],
       repeat: data["repeat"] || false
     }}
  end

  defp dispatch(
         %{
           "type" => "event",
           "family" => "key_release",
           "value" => key,
           "modifiers" => mods
         } = msg
       ) do
    data = msg["data"] || %{}

    {:key_release,
     %Julep.KeyEvent{
       key: parse_key(key),
       modified_key: parse_key(data["modified_key"] || key),
       physical_key: parse_physical_key(data["physical_key"]),
       location: parse_location(data["location"]),
       modifiers: parse_modifiers(mods),
       text: nil,
       repeat: false
     }}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "modifiers_changed",
         "modifiers" => mods
       }) do
    {:modifiers_changed, parse_modifiers(mods)}
  end

  # -- Mouse events --

  defp dispatch(%{"type" => "event", "family" => "cursor_moved", "data" => %{"x" => x, "y" => y}}) do
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
         "data" => %{"delta_x" => dx, "delta_y" => dy, "unit" => unit}
       }) do
    {:wheel_scrolled, dx, dy, unit}
  end

  # -- IME events --

  defp dispatch(%{
         "type" => "event",
         "family" => "ime",
         "data" => %{"kind" => "opened"}
       }) do
    {:ime_opened}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "ime",
         "data" => %{"kind" => "preedit", "text" => text, "cursor" => %{"start" => s, "end" => e}}
       }) do
    {:ime_preedit, text, {s, e}}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "ime",
         "data" => %{"kind" => "preedit", "text" => text}
       }) do
    {:ime_preedit, text, nil}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "ime",
         "data" => %{"kind" => "commit", "text" => text}
       }) do
    {:ime_commit, text}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "ime",
         "data" => %{"kind" => "closed"}
       }) do
    {:ime_closed}
  end

  # -- Touch events --

  defp dispatch(%{
         "type" => "event",
         "family" => "finger_pressed",
         "data" => %{"finger_id" => finger_id, "x" => x, "y" => y}
       }) do
    {:finger_pressed, finger_id, x, y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "finger_moved",
         "data" => %{"finger_id" => finger_id, "x" => x, "y" => y}
       }) do
    {:finger_moved, finger_id, x, y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "finger_lifted",
         "data" => %{"finger_id" => finger_id, "x" => x, "y" => y}
       }) do
    {:finger_lifted, finger_id, x, y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "finger_lost",
         "data" => %{"finger_id" => finger_id, "x" => x, "y" => y}
       }) do
    {:finger_lost, finger_id, x, y}
  end

  # -- Window lifecycle events --

  defp dispatch(%{
         "type" => "event",
         "family" => "window_opened",
         "data" => %{"window_id" => window_id, "width" => width, "height" => height} = data
       }) do
    pos =
      case data do
        %{"position" => %{"x" => x, "y" => y}} -> {x, y}
        _ -> nil
      end

    {:window_opened, window_id, pos, {width, height}}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_closed",
         "data" => %{"window_id" => window_id}
       }) do
    {:window_closed, window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_close_requested",
         "data" => %{"window_id" => window_id}
       }) do
    {:window_close_requested, window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_moved",
         "data" => %{"window_id" => window_id, "x" => x, "y" => y}
       }) do
    {:window_moved, window_id, x, y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_resized",
         "data" => %{"window_id" => window_id, "width" => width, "height" => height}
       }) do
    {:window_resized, window_id, width, height}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_focused",
         "data" => %{"window_id" => window_id}
       }) do
    {:window_focused, window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_unfocused",
         "data" => %{"window_id" => window_id}
       }) do
    {:window_unfocused, window_id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "window_rescaled",
         "data" => %{"window_id" => window_id, "scale_factor" => scale_factor}
       }) do
    {:window_rescaled, window_id, scale_factor}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "file_hovered",
         "data" => %{"window_id" => window_id, "path" => path}
       }) do
    {:file_hovered, window_id, path}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "file_dropped",
         "data" => %{"window_id" => window_id, "path" => path}
       }) do
    {:file_dropped, window_id, path}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "files_hovered_left",
         "data" => %{"window_id" => window_id}
       }) do
    {:files_hovered_left, window_id}
  end

  # -- Animation / theme / system events --

  defp dispatch(%{
         "type" => "event",
         "family" => "animation_frame",
         "data" => %{"timestamp" => timestamp}
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

  # -- MouseArea events --

  defp dispatch(%{"type" => "event", "family" => "mouse_right_press", "id" => id}) do
    {:mouse_right_press, id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_right_release", "id" => id}) do
    {:mouse_right_release, id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_middle_press", "id" => id}) do
    {:mouse_middle_press, id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_middle_release", "id" => id}) do
    {:mouse_middle_release, id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_double_click", "id" => id}) do
    {:mouse_double_click, id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_enter", "id" => id}) do
    {:mouse_enter, id}
  end

  defp dispatch(%{"type" => "event", "family" => "mouse_exit", "id" => id}) do
    {:mouse_exit, id}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "mouse_move",
         "id" => id,
         "data" => %{"x" => x, "y" => y}
       }) do
    {:mouse_move, id, x, y}
  end

  defp dispatch(%{
         "type" => "event",
         "family" => "mouse_scroll",
         "id" => id,
         "data" => %{"delta_x" => dx, "delta_y" => dy}
       }) do
    {:mouse_scroll, id, dx, dy}
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

  defp dispatch(%{"type" => "event", "family" => "sort", "id" => id, "data" => data}) do
    {:sort, id, data["column"]}
  end

  defp dispatch(%{"type" => "event", "family" => "scroll", "id" => id, "data" => data}) do
    {:scroll, id,
     %{
       absolute_x: data["absolute_x"],
       absolute_y: data["absolute_y"],
       relative_x: data["relative_x"],
       relative_y: data["relative_y"],
       bounds: {data["bounds_width"], data["bounds_height"]},
       content_bounds: {data["content_width"], data["content_height"]}
     }}
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

  # -- System query responses --

  defp dispatch(%{
         "type" => "query_response",
         "kind" => "system_info",
         "tag" => tag,
         "data" => data
       }) do
    {:system_info, tag, data}
  end

  defp dispatch(%{
         "type" => "query_response",
         "kind" => "system_theme",
         "tag" => tag,
         "data" => data
       }) do
    {:system_theme, tag, data}
  end

  defp dispatch(msg) do
    {:error, {:unknown_message, msg}}
  end
end
