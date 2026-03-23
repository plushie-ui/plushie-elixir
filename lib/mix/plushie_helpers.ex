defmodule Mix.PlushieHelpers do
  @moduledoc false

  @doc """
  Returns the path to the plushie source checkout, or nil.

  Checked in order:
  1. `PLUSHIE_SOURCE_PATH` environment variable
  2. `config :plushie, :source_path`
  """
  @spec source_path() :: String.t() | nil
  def source_path do
    System.get_env("PLUSHIE_SOURCE_PATH") ||
      Application.get_env(:plushie, :source_path)
  end

  @doc """
  Returns the path to the plushie source checkout, or raises.
  """
  @spec source_path!() :: String.t()
  def source_path! do
    source_path() ||
      raise """
      plushie source path not configured.

      Set one of:
        export PLUSHIE_SOURCE_PATH=/path/to/plushie
        config :plushie, :source_path, "/path/to/plushie"
      """
  end

  @doc "Returns the expected path to the built plushie binary in the source tree."
  @spec built_binary_path(release? :: boolean()) :: String.t()
  def built_binary_path(release?) do
    profile = if release?, do: "release", else: "debug"
    Path.join([source_path!(), "target", profile, "plushie-renderer"])
  end

  @doc """
  Resolves the plushie binary path for a mix task.

  When `--build` is passed, delegates to `mix plushie.build` and returns
  the expected output path. Otherwise uses `Plushie.Binary.path!/0`.
  """
  @spec resolve_binary!(opts :: keyword()) :: String.t()
  def resolve_binary!(opts) do
    if opts[:build] do
      build_args = if opts[:release], do: ["--release"], else: []
      Mix.Task.run("plushie.build", build_args)
      built_binary_path(opts[:release] || false)
    else
      Plushie.Binary.path!()
    end
  end
end
