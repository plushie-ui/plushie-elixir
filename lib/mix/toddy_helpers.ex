defmodule Mix.ToddyHelpers do
  @moduledoc false

  @doc """
  Returns the path to the toddy source checkout, or nil.

  Checked in order:
  1. `TODDY_SOURCE_PATH` environment variable
  2. `config :toddy, :source_path`
  """
  @spec source_path() :: String.t() | nil
  def source_path do
    System.get_env("TODDY_SOURCE_PATH") ||
      Application.get_env(:toddy, :source_path)
  end

  @doc """
  Returns the path to the toddy source checkout, or raises.
  """
  @spec source_path!() :: String.t()
  def source_path! do
    source_path() ||
      raise """
      toddy source path not configured.

      Set one of:
        export TODDY_SOURCE_PATH=/path/to/toddy
        config :toddy, :source_path, "/path/to/toddy"
      """
  end

  @doc "Returns the expected path to the built toddy binary in the source tree."
  @spec built_binary_path(release? :: boolean()) :: String.t()
  def built_binary_path(release?) do
    profile = if release?, do: "release", else: "debug"
    Path.join([source_path!(), "target", profile, "toddy"])
  end

  @doc """
  Resolves the toddy binary path for a mix task.

  When `--build` is passed, delegates to `mix toddy.build` and returns
  the expected output path. Otherwise uses `Toddy.Binary.path!/0`.
  """
  @spec resolve_binary!(opts :: keyword()) :: String.t()
  def resolve_binary!(opts) do
    if opts[:build] do
      build_args = if opts[:release], do: ["--release"], else: []
      Mix.Task.run("toddy.build", build_args)
      built_binary_path(opts[:release] || false)
    else
      Toddy.Binary.path!()
    end
  end
end
