defmodule Mix.JulepHelpers do
  @moduledoc false

  @doc "Returns the path to the julep source checkout."
  @spec renderer_source_path() :: String.t()
  def renderer_source_path do
    System.get_env("JULEP_RENDERER_SOURCE") ||
      Application.get_env(:julep, :renderer_source) ||
      Path.expand("../julep")
  end

  @doc "Returns the expected path to the built julep binary."
  @spec renderer_binary_path(release? :: boolean()) :: String.t()
  def renderer_binary_path(release?) do
    profile = if release?, do: "release", else: "debug"
    Path.join([renderer_source_path(), "target", profile, "julep"])
  end
end
