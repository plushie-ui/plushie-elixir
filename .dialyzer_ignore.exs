[
  # :httpc.request/4 is part of :inets but dialyzer can't resolve it on
  # some OTP versions. The calls work fine at runtime -- inets is started
  # explicitly before each call.
  {"lib/mix/tasks/plushie.download.ex", :unknown_function},

  # MapSet.t() is opaque, and dialyzer flags any struct that contains a
  # MapSet field when the struct is constructed or returned. This is a
  # known dialyzer limitation with opaque types inside structs. The code
  # is correct -- it only uses MapSet API functions, never inspects internals.
  {"lib/plushie/selection.ex", :contract_with_opaque},
  {"lib/plushie/runtime/windows.ex", :contract_with_opaque},
  {"lib/plushie/runtime/windows.ex", :call_without_opaque},

  # Same MapSet opaque issue -- renderer_restarted handler resets windows
  # to MapSet.new() before calling sync_windows, which dialyzer flags.
  {"lib/plushie/runtime.ex", :call_without_opaque},

]
