defmodule Plushie.Test.Backend.Headless do
  @moduledoc """
  Headless test backend using the Rust renderer with iced_test Simulator.

  Spawns `plushie --headless` as a Port and communicates via the negotiated
  wire format (msgpack by default, json opt-in). Provides structural tree
  snapshots and real widget rendering for regression testing. No display server
  required.

  ## Requirements

  Build the renderer:

      mix plushie.build

  ## Limitations

  - No real windows or GPU rendering (use `:windowed` for that).
  - Effects (file dialogs, clipboard) return `:cancelled`.
  - Subscriptions are tracked but not fired (no event loop).

  ## When to use

  Visual regression testing and protocol round-trip verification. Proves
  wire format correctness end-to-end without needing a display server.
  """

  use Plushie.Test.Backend.RendererBase, call_timeout: 10_000

  @impl GenServer
  def init({app, opts}) do
    format = Keyword.get(opts, :format, :msgpack)
    renderer_path = Keyword.fetch!(opts, :renderer)

    env = Plushie.RendererEnv.build()

    port =
      Port.open({:spawn_executable, renderer_path}, [
        :binary,
        :exit_status,
        :use_stdio
        | port_opts(format) ++ [{:args, port_args(format)}, {:env, env}]
      ])

    {state, tree} = build_state(port, format, app, opts)

    # Headless sends only the initial snapshot (no settings message)
    send_message(port, format, %{type: "snapshot", tree: tree})

    {:ok, state}
  end

  defp port_args(:json), do: ["--headless", "--json"]
  defp port_args(:msgpack), do: ["--headless"]

  defp screenshot_payload(name) do
    %{type: "screenshot", name: name, width: 1024, height: 768}
  end
end
