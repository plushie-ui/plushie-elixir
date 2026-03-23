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

  @doc """
  Resolves which artifacts to install/download.

  Resolution: CLI flags > `config :plushie, :artifacts` > `[:bin]`.

  CLI flags (`--bin`, `--wasm`, `--bin-file`, `--wasm-dir`) override
  everything. The `:artifacts` config lets a project declare its needs
  once (e.g. `[:bin, :wasm]`) so commands work without flags.
  """
  @spec resolve_artifacts(opts :: keyword()) :: {boolean(), boolean()}
  def resolve_artifacts(opts) do
    # CLI path flags imply their target
    cli_bin? = opts[:bin] || opts[:bin_file] != nil
    cli_wasm? = opts[:wasm] || opts[:wasm_dir] != nil

    if cli_bin? or cli_wasm? do
      # Explicit CLI flags -- use them directly
      {cli_bin?, cli_wasm?}
    else
      # Fall back to config, then default
      configured = Application.get_env(:plushie, :artifacts, [:bin])

      {
        :bin in configured,
        :wasm in configured
      }
    end
  end

  @doc """
  Resolves the binary output path.

  Resolution: CLI `--bin-file` > `config :plushie, :bin_file` > default.
  """
  @spec resolve_bin_file(opts :: keyword()) :: String.t()
  def resolve_bin_file(opts) do
    opts[:bin_file] ||
      Application.get_env(:plushie, :bin_file) ||
      Path.join(Plushie.Binary.download_dir(), Plushie.Binary.download_name())
  end

  @doc """
  Resolves the WASM output directory.

  Resolution: CLI `--wasm-dir` > `config :plushie, :wasm_dir` > default.
  """
  @spec resolve_wasm_dir(opts :: keyword()) :: String.t()
  def resolve_wasm_dir(opts) do
    opts[:wasm_dir] ||
      Application.get_env(:plushie, :wasm_dir) ||
      Path.join(["_build", "plushie-renderer", "wasm"])
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
