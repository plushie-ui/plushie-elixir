defmodule Plushie.Event.DiagnosticMessage do
  @moduledoc """
  A structured diagnostic delivered through the renderer's diagnostic
  wire channel.

  Wire shape: `%{type: "diagnostic", session, level, diagnostic: %{kind, ...}}`.
  The `:diagnostic` field is one of the typed variants defined under
  `Plushie.Event.Diagnostic.*`.

  ## Fields

    * `:session` - session ID the diagnostic is attributed to. An
      empty string for process-scoped diagnostics (font load failures,
      renderer startup or panic, writer-dead, anything that affects
      the whole renderer rather than a single session). Non-empty for
      session-scoped diagnostics (widget panics, view errors, tree
      validation warnings, anything produced inside a session's
      update or apply pipeline).
    * `:level` - severity: `:info`, `:warn`, or `:error`.
    * `:diagnostic` - typed diagnostic variant struct.

  ## Pattern matching

      def update(model, %DiagnosticMessage{diagnostic: %FontFamilyNotFound{family: f}}) do
        Logger.warning("font missing: \#{f}")
        model
      end

      def update(model, %DiagnosticMessage{level: :error, diagnostic: diag}) do
        Logger.error("plushie renderer error: \#{inspect(diag)}")
        model
      end
  """

  @enforce_keys [:session, :level, :diagnostic]
  defstruct [:session, :level, :diagnostic]

  @type level :: :info | :warn | :error

  @type t :: %__MODULE__{
          session: String.t(),
          level: level(),
          diagnostic: Plushie.Event.Diagnostic.t()
        }
end
