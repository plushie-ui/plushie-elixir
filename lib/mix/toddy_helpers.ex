defmodule Mix.ToddyHelpers do
  @moduledoc false

  @doc "Returns the path to the toddy source checkout."
  @spec renderer_source_path() :: String.t()
  def renderer_source_path do
    System.get_env("TODDY_RENDERER_SOURCE") ||
      Application.get_env(:toddy, :renderer_source) ||
      Path.expand("../toddy")
  end

  @doc "Returns the expected path to the built toddy binary."
  @spec renderer_binary_path(release? :: boolean()) :: String.t()
  def renderer_binary_path(release?) do
    profile = if release?, do: "release", else: "debug"
    Path.join([renderer_source_path(), "target", profile, "toddy"])
  end
end
