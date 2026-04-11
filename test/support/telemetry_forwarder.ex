defmodule Plushie.Test.TelemetryForwarder do
  @moduledoc false

  # Module-level telemetry handler that forwards events to a test process.
  # Using a module function avoids the "local function" info log from
  # the telemetry library.
  #
  # Usage:
  #
  #     :telemetry.attach(
  #       "handler-id",
  #       [:plushie, :some, :event],
  #       &Plushie.Test.TelemetryForwarder.handle/4,
  #       %{pid: self(), tag: :my_event}
  #     )
  #
  # The test process receives `{tag, metadata}`.
  # With `include_event: true`, receives `{tag, event, measurements}`.

  def handle(event, measurements, _metadata, %{pid: pid, tag: tag, include_event: true}) do
    send(pid, {tag, event, measurements})
  end

  def handle(_event, _measurements, metadata, %{pid: pid, tag: tag}) do
    send(pid, {tag, metadata})
  end
end
