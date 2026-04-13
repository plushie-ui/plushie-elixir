[
  # MapSet.t() is opaque, and dialyzer flags any struct that contains a
  # MapSet field when the struct is constructed or returned. This is a
  # known dialyzer limitation with opaque types inside structs. The code
  # is correct: it only uses MapSet API functions, never inspects internals.
  {"lib/plushie/selection.ex", :contract_with_opaque},
  {"lib/plushie/runtime/windows.ex", :contract_with_opaque},
  {"lib/plushie/runtime/windows.ex", :call_without_opaque},
  {"lib/plushie/runtime/widget_handlers.ex", :contract_with_opaque},
  {"lib/plushie/type/theme.ex", :contract_with_opaque},

  # Same MapSet opaque issue. The renderer_restarted handler resets windows
  # to MapSet.new() before calling sync_windows, which dialyzer flags.
  {"lib/plushie/runtime.ex", :call_without_opaque},

  # :erl_tar.extract/2 typespec does not include {:safe_relative_path, true}
  # in OTP 28's dialyzer PLT, but the option works at runtime.
  {"lib/mix/tasks/plushie.download.ex", :no_return},
]
