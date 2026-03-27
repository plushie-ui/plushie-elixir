defmodule Plushie.Test.SessionPool.Transport do
  @moduledoc """
  Transport helpers for `Plushie.Test.SessionPool`.

  This module owns renderer process startup and wire writes so the pool and
  mode-specific state machines do not need to know about Port setup details.
  """

  @typedoc "Wire format used between the Elixir test backend and the renderer."
  @type format :: :json | :msgpack

  @spec renderer_mode_flag(:mock | :headless) :: String.t()
  def renderer_mode_flag(:mock), do: "--mock"
  def renderer_mode_flag(:headless), do: "--headless"

  @spec send_to_port(port(), format(), map()) :: true
  def send_to_port(port, format, msg) do
    data = Plushie.Protocol.encode(msg, format)
    Port.command(port, data)
  end

  @spec send_initial_settings(port(), format(), String.t()) :: true
  def send_initial_settings(port, format, session_id) do
    settings = %{protocol_version: Plushie.Protocol.protocol_version()}
    send_to_port(port, format, %{session: session_id, type: "settings", settings: settings})
  end

  @spec open_renderer_port(String.t(), [{String.t(), String.t()}], format(), [String.t()]) ::
          port()
  def open_renderer_port(renderer_path, env, format, args) do
    port_opts =
      [:binary, :exit_status, :use_stdio] ++
        if(format == :json, do: [{:line, 65_536}], else: [{:packet, 4}])

    Port.open(
      {:spawn_executable, renderer_path},
      port_opts ++ [{:args, args}, {:env, env}]
    )
  end

  @spec multiplexed_args(:mock | :headless, format(), pos_integer()) :: [String.t()]
  def multiplexed_args(mode, format, max_sessions) do
    [renderer_mode_flag(mode), "--max-sessions", to_string(max_sessions)] ++
      if(format == :json, do: ["--json"], else: [])
  end

  @spec windowed_args(format()) :: [String.t()]
  def windowed_args(format) do
    if format == :json, do: ["--json"], else: ["--msgpack"]
  end
end
