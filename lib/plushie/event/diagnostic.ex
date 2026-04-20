defmodule Plushie.Event.Diagnostic do
  @moduledoc """
  Typed diagnostic variants emitted by the renderer.

  The renderer's `plushie-core::Diagnostic` enum enumerates every
  diagnostic the renderer can emit (tree normalization warnings, prop
  validation, font cap, panic guards, transport violations). Each
  variant arrives on the wire as a map with a discriminator
  (`"kind": "..."`) and variant-specific fields. `decode!/1` dispatches
  on that discriminator to one of the structs defined here so app
  authors pattern match on a typed struct rather than a raw map.

  Decoded diagnostics are delivered through
  `Plushie.Event.DiagnosticMessage`, which carries the session ID,
  severity level, and the typed diagnostic. Apps typically match both:

      def update(model, %DiagnosticMessage{diagnostic: %FontFamilyNotFound{family: f}}) do
        Logger.warning("font missing: \#{f}")
        model
      end

  ## Unknown variants

  The decoder raises `ArgumentError` on an unrecognised `kind`. A new
  renderer variant requires an SDK update; silently dropping unknown
  diagnostics would hide host/renderer version skew that the runtime
  needs to see.
  """

  alias Plushie.Event.Diagnostic.{
    A11yRefUnresolved,
    BufferOverflow,
    ContentLengthExceeded,
    DashCacheCapExceeded,
    DispatchLoopExceeded,
    DuplicateId,
    EmitterCoalesceCapExceeded,
    EmptyId,
    FontCacheCapExceeded,
    FontCapExceeded,
    FontFamilyNotFound,
    InvalidSettings,
    MissingAccessibleName,
    MultipleTopLevelWindows,
    PropRangeExceeded,
    PropTypeMismatch,
    PropUnknown,
    RequiredWidgetsMissing,
    SvgDecodeTimeout,
    SvgParseError,
    TooManyDuplicates,
    TreeDepthExceeded,
    UnknownMessageType,
    UnknownWindow,
    UnrecognizedWidgetPlaceholder,
    UpdatePanicked,
    ViewPanicked,
    WidgetIdInvalid,
    WidgetIdTypeCollision,
    WidgetPanic
  }

  @kinds %{
    "duplicate_id" => DuplicateId,
    "empty_id" => EmptyId,
    "multiple_top_level_windows" => MultipleTopLevelWindows,
    "unknown_window" => UnknownWindow,
    "unrecognized_widget_placeholder" => UnrecognizedWidgetPlaceholder,
    "tree_depth_exceeded" => TreeDepthExceeded,
    "too_many_duplicates" => TooManyDuplicates,
    "widget_id_invalid" => WidgetIdInvalid,
    "missing_accessible_name" => MissingAccessibleName,
    "a11y_ref_unresolved" => A11yRefUnresolved,
    "prop_range_exceeded" => PropRangeExceeded,
    "prop_type_mismatch" => PropTypeMismatch,
    "prop_unknown" => PropUnknown,
    "content_length_exceeded" => ContentLengthExceeded,
    "font_cache_cap_exceeded" => FontCacheCapExceeded,
    "font_cap_exceeded" => FontCapExceeded,
    "font_family_not_found" => FontFamilyNotFound,
    "invalid_settings" => InvalidSettings,
    "required_widgets_missing" => RequiredWidgetsMissing,
    "widget_panic" => WidgetPanic,
    "svg_parse_error" => SvgParseError,
    "svg_decode_timeout" => SvgDecodeTimeout,
    "dash_cache_cap_exceeded" => DashCacheCapExceeded,
    "emitter_coalesce_cap_exceeded" => EmitterCoalesceCapExceeded,
    "widget_id_type_collision" => WidgetIdTypeCollision,
    "view_panicked" => ViewPanicked,
    "update_panicked" => UpdatePanicked,
    "unknown_message_type" => UnknownMessageType,
    "dispatch_loop_exceeded" => DispatchLoopExceeded,
    "buffer_overflow" => BufferOverflow
  }

  @typedoc """
  Any typed diagnostic variant struct.
  """
  @type t ::
          DuplicateId.t()
          | EmptyId.t()
          | MultipleTopLevelWindows.t()
          | UnknownWindow.t()
          | UnrecognizedWidgetPlaceholder.t()
          | TreeDepthExceeded.t()
          | TooManyDuplicates.t()
          | WidgetIdInvalid.t()
          | MissingAccessibleName.t()
          | A11yRefUnresolved.t()
          | PropRangeExceeded.t()
          | PropTypeMismatch.t()
          | PropUnknown.t()
          | ContentLengthExceeded.t()
          | FontCacheCapExceeded.t()
          | FontCapExceeded.t()
          | FontFamilyNotFound.t()
          | InvalidSettings.t()
          | RequiredWidgetsMissing.t()
          | WidgetPanic.t()
          | SvgParseError.t()
          | SvgDecodeTimeout.t()
          | DashCacheCapExceeded.t()
          | EmitterCoalesceCapExceeded.t()
          | WidgetIdTypeCollision.t()
          | ViewPanicked.t()
          | UpdatePanicked.t()
          | UnknownMessageType.t()
          | DispatchLoopExceeded.t()
          | BufferOverflow.t()

  @doc """
  Decode a typed diagnostic from a wire payload map.

  The payload is the value of the `diagnostic` field on the top-level
  `diagnostic` wire message: a map containing `"kind"` plus variant-
  specific fields.

  Raises `ArgumentError` on an unknown `kind`.
  """
  @spec decode!(map()) :: t()
  def decode!(%{"kind" => kind} = payload) when is_map(payload) do
    case Map.fetch(@kinds, kind) do
      {:ok, module} ->
        module.from_wire(payload)

      :error ->
        raise ArgumentError,
              "unknown diagnostic kind #{inspect(kind)}. The renderer emitted " <>
                "a diagnostic this SDK version does not recognize. Ensure the " <>
                "SDK and renderer versions are compatible."
    end
  end

  def decode!(other) do
    raise ArgumentError,
          "diagnostic payload must be a map with a \"kind\" field, got #{inspect(other)}"
  end

  @doc """
  List of wire-level kind strings this SDK version decodes.

  Useful for test assertions that the SDK's typed-variant coverage
  matches the renderer's enum.
  """
  @spec known_kinds() :: [String.t()]
  def known_kinds, do: Map.keys(@kinds)
end
