defmodule Julep.Test.Backend.Full do
  @moduledoc """
  Full test backend with real iced windows.

  Spawns `julep_gui --test` which runs a real `iced::daemon` with GPU
  rendering, but also accepts test protocol messages (Query, Interact,
  SnapshotCapture, Reset) on stdin alongside normal Snapshot/Patch messages.

  ## Requirements

  Build the renderer with test-mode support:

      cd native/julep_gui && cargo build --features test-mode

  For CI (headless environment), use Xvfb:

      sudo apt-get install -y xvfb mesa-vulkan-drivers
      Xvfb :99 -screen 0 1024x768x24 &
      export DISPLAY=:99
      export WINIT_UNIX_BACKEND=x11

  ## Capabilities

  - Real windows open and render via wgpu.
  - Effects (file dialogs, clipboard, notifications) actually work.
  - Subscriptions fire normally.
  - Screenshots capture actual GPU-rendered pixels.
  - Interactions inject real Messages into the iced runtime.

  ## When to use

  End-to-end integration tests that verify the full stack including window
  lifecycle, real rendering, and platform effects. Slowest backend but
  highest confidence.
  """

  use Julep.Test.Backend.RendererBase, call_timeout: 15_000

  @impl GenServer
  def init({app, opts}) do
    unless System.get_env("DISPLAY") || System.get_env("WAYLAND_DISPLAY") do
      raise "Full backend requires DISPLAY or WAYLAND_DISPLAY env var (use Xvfb in CI)"
    end

    format = Keyword.get(opts, :format, :msgpack)
    renderer_path = Julep.Binary.renderer_path()

    port =
      Port.open({:spawn_executable, renderer_path}, [
        :binary,
        :exit_status,
        :use_stdio
        | port_opts(format) ++ [{:args, port_args(format)}]
      ])

    # Full backend sends settings first (required by the daemon's
    # read_initial_settings), then the initial snapshot.
    send_message(port, format, %{type: "settings", settings: %{}})

    {state, tree} = build_state(port, format, app, opts)

    # Send initial snapshot -- this will open real windows
    send_message(port, format, %{type: "snapshot", tree: tree})

    {:ok, state}
  end

  defp port_args(:json), do: ["--test", "--json"]
  defp port_args(:msgpack), do: ["--test"]

  defp screenshot_payload(name) do
    %{type: "screenshot_capture", name: name}
  end
end
