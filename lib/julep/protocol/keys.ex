defmodule Julep.Protocol.Keys do
  @moduledoc false

  # Named key and physical key maps, plus the `parse_key/1` public API.

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

      iex> Julep.Protocol.Keys.parse_key("Escape")
      :escape

      iex> Julep.Protocol.Keys.parse_key("a")
      "a"
  """
  @spec parse_key(key :: String.t()) :: atom() | String.t()
  def parse_key(key) when is_binary(key) do
    Map.get(@named_keys, key, key)
  end

  @doc """
  Converts a physical key code string to an atom, or returns the string
  unchanged for unknown codes.
  """
  @spec parse_physical_key(String.t() | nil) :: atom() | String.t() | nil
  def parse_physical_key(nil), do: nil

  def parse_physical_key(str) when is_binary(str) do
    Map.get(@physical_keys, str, str)
  end

  @doc "Parses a key location string to an atom."
  @spec parse_location(String.t() | nil) :: :left | :right | :numpad | :standard
  def parse_location("left"), do: :left
  def parse_location("right"), do: :right
  def parse_location("numpad"), do: :numpad
  def parse_location(_), do: :standard
end
