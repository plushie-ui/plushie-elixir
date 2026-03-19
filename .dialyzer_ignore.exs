[
  # :httpc.request/4 is part of :inets but dialyzer can't resolve it on
  # some OTP versions. The calls work fine at runtime -- inets is started
  # explicitly before each call.
  {"lib/mix/tasks/toddy.download.ex", :unknown_function},

  # MapSet.t() is opaque, and dialyzer flags any struct that contains a
  # MapSet field when the struct is constructed or returned. This is a
  # known dialyzer limitation with opaque types inside structs. The code
  # is correct -- it only uses MapSet API functions, never inspects internals.
  {"lib/toddy/selection.ex", :contract_with_opaque},
  {"lib/toddy/runtime/windows.ex", :contract_with_opaque},
  {"lib/toddy/runtime/windows.ex", :call_without_opaque},

  # Convenience alignment builders return t() which is correct, but dialyzer
  # infers a more specific success type (e.g. align_x: :left). The spec is
  # accurate -- t() subsumes the specific field values.
  {"lib/toddy/iced/widget/container.ex", :invalid_contract},

]
