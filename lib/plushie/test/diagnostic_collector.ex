defmodule Plushie.Test.DiagnosticCollector do
  @moduledoc false

  # Collects diagnostic telemetry events for test assertions.
  # Uses the process dictionary to store diagnostics per test process,
  # avoiding cross-test interference in async test suites.

  @key :plushie_test_diagnostics

  @doc "Attach the telemetry handler for the current process."
  @spec attach() :: :ok
  def attach do
    Process.put(@key, [])
    handler_id = "plushie-diagnostic-#{inspect(self())}"

    pid = self()

    :telemetry.attach(
      handler_id,
      [:plushie, :diagnostic],
      fn _event, _measurements, metadata, _ ->
        send(pid, {:plushie_diagnostic, metadata})
      end,
      nil
    )

    :ok
  end

  @doc "Detach the telemetry handler for the current process."
  @spec detach() :: :ok
  def detach do
    handler_id = "plushie-diagnostic-#{inspect(self())}"
    :telemetry.detach(handler_id)
    Process.delete(@key)
    :ok
  end

  @doc "Drain any diagnostic messages from the mailbox and return all collected diagnostics."
  @spec flush() :: [map()]
  def flush do
    drain_mailbox()
    diagnostics = Process.get(@key, [])
    Process.put(@key, [])
    Enum.reverse(diagnostics)
  end

  defp drain_mailbox do
    receive do
      {:plushie_diagnostic, metadata} ->
        existing = Process.get(@key, [])
        Process.put(@key, [metadata | existing])
        drain_mailbox()
    after
      0 -> :ok
    end
  end
end
