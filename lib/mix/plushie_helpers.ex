defmodule Mix.PlushieHelpers do
  @moduledoc false

  @doc """
  Returns the path to the plushie-rust source checkout, or nil.

  Checked in order:
  1. `PLUSHIE_RUST_SOURCE_PATH` environment variable
  2. `config :plushie, :source_path`
  """
  @spec source_path() :: String.t() | nil
  def source_path do
    System.get_env("PLUSHIE_RUST_SOURCE_PATH") ||
      Application.get_env(:plushie, :source_path)
  end

  @doc """
  Returns the path to the plushie-rust source checkout, or raises.
  """
  @spec source_path!() :: String.t()
  def source_path! do
    source_path() ||
      raise """
      plushie-rust source path not configured.

      Set one of:
        export PLUSHIE_RUST_SOURCE_PATH=/path/to/plushie-rust
        config :plushie, :source_path, "/path/to/plushie-rust"
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
      # Explicit CLI flags: use them directly
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

  @doc """
  Resolves the plushie binary path for a mix task.

  When `--build` is passed, delegates to `mix plushie.build` and returns
  the installed output path. Otherwise uses `Plushie.Binary.path!/0`.

  Raises if `--release` is passed without `--build`, since `--release`
  only controls the build profile and has no effect on binary resolution.
  """
  @spec resolve_binary!(opts :: keyword()) :: String.t()
  def resolve_binary!(opts) do
    if opts[:release] && !opts[:build] do
      Mix.raise("--release requires --build (it controls the build profile)")
    end

    if opts[:build] do
      build_args = if opts[:release], do: ["--release"], else: []
      Mix.Task.run("plushie.build", build_args)
      resolve_bin_file(opts)
    else
      Plushie.Binary.path!()
    end
  end

  @doc false
  @spec compile_project!(args :: [String.t()]) :: :ok
  def compile_project!(args \\ []) do
    args = Enum.uniq(args ++ ["--return-errors"])

    case Mix.Task.run("compile", args) do
      :noop ->
        :ok

      {:error, _diagnostics} ->
        Mix.raise("Compilation failed")

      {_status, _diagnostics} ->
        :ok
    end
  end

  @doc """
  Resolves how to invoke `cargo-plushie` for renderer workspace generation.

  Returns `{command, args_prefix}`. Callers append their own cargo-plushie
  subcommand and flags after the prefix, for example:

      {cmd, prefix} = Mix.PlushieHelpers.resolve_cargo_plushie()
      args = prefix ++ ["build", "--manifest-path", path]
      System.cmd(cmd, args)

  Resolution:

  1. When `PLUSHIE_RUST_SOURCE_PATH` is set, run the tool straight from
     the source checkout via `cargo run -p cargo-plushie --release`.
     This always works while cargo-plushie is still unpublished and
     keeps the tool in lockstep with the local source tree.
  2. Otherwise, use `cargo-plushie` from PATH if installed at the exact
     version this SDK targets (`plushie_rust_version/0`).
  3. Raises with an install instruction if cargo-plushie is absent or
     its version does not match.
  """
  @spec resolve_cargo_plushie() :: {String.t(), [String.t()]}
  def resolve_cargo_plushie do
    case source_path() do
      nil ->
        resolve_cargo_plushie_from_path()

      source ->
        manifest = Path.join(Path.expand(source), "Cargo.toml")

        unless File.exists?(manifest) do
          Mix.raise("""
          PLUSHIE_RUST_SOURCE_PATH points to #{inspect(source)} but no \
          Cargo.toml was found at #{manifest}. Fix the path or unset the \
          variable to use the registry-installed cargo-plushie.
          """)
        end

        {"cargo", ["run", "--manifest-path", manifest, "-p", "cargo-plushie", "--release", "--"]}
    end
  end

  # Resolves via a crates.io-installed `cargo-plushie` on PATH.
  # Extracted for clean injection in tests.
  @doc false
  @spec resolve_cargo_plushie_from_path() :: {String.t(), [String.t()]}
  def resolve_cargo_plushie_from_path do
    case installed_cargo_plushie_version() do
      {:ok, version} ->
        expected = Plushie.Binary.plushie_rust_version()

        if version == expected do
          {"cargo-plushie", []}
        else
          Mix.raise(cargo_plushie_install_message(expected, {:mismatch, version}))
        end

      :error ->
        Mix.raise(cargo_plushie_install_message(Plushie.Binary.plushie_rust_version(), :missing))
    end
  end

  # Reads `cargo-plushie --version` and extracts the semver string. Test
  # hook: swap out via `:persistent_term.put({__MODULE__, :cargo_plushie_version}, value)`.
  # The persistent_term value, if set, must be `{:ok, "x.y.z"}` or `:error`.
  @spec installed_cargo_plushie_version() :: {:ok, String.t()} | :error
  defp installed_cargo_plushie_version do
    case :persistent_term.get({__MODULE__, :cargo_plushie_version}, :unset) do
      :unset -> probe_cargo_plushie_version()
      override -> override
    end
  end

  @spec probe_cargo_plushie_version() :: {:ok, String.t()} | :error
  defp probe_cargo_plushie_version do
    if System.find_executable("cargo-plushie") do
      case System.cmd("cargo-plushie", ["--version"], stderr_to_stdout: true) do
        {output, 0} ->
          case Regex.run(~r/(\d+\.\d+\.\d+)/, output) do
            [_, version] -> {:ok, version}
            _ -> :error
          end

        _ ->
          :error
      end
    else
      :error
    end
  rescue
    ErlangError -> :error
  end

  @spec cargo_plushie_install_message(String.t(), :missing | {:mismatch, String.t()}) ::
          String.t()
  defp cargo_plushie_install_message(expected, state) do
    prefix =
      case state do
        :missing ->
          "cargo-plushie is not installed."

        {:mismatch, found} ->
          "cargo-plushie version mismatch: installed #{found}, expected #{expected}."
      end

    """
    error: #{prefix}

      Install the matching version:
        cargo install cargo-plushie --version #{expected} --locked

      Or set PLUSHIE_RUST_SOURCE_PATH to a plushie-rust checkout for local dev.\
    """
  end

  @doc "Validates that a module is loaded. Raises with a clear message if not."
  @spec validate_module!(module :: module()) :: :ok
  def validate_module!(mod) when is_atom(mod) do
    unless Code.ensure_loaded?(mod) do
      Mix.raise("""
      Module #{inspect(mod)} could not be loaded.

      Make sure the module name is correct and the project compiles.
      """)
    end

    :ok
  end

  def validate_module!(mod) do
    Mix.raise("Module name must be an atom, got: #{inspect(mod)}")
  end

  @doc """
  Warns when `path` is not gitignored inside the current git work tree.

  Silent when not in a git repo or when the path is already ignored.
  Intended for output paths that hold generated artifacts (`bin/`,
  `dist/`) so users don't accidentally commit them.
  """
  @spec warn_if_not_gitignored(path :: String.t()) :: :ok
  def warn_if_not_gitignored(path) do
    relative = path |> Path.relative_to_cwd() |> String.trim_trailing("/")

    if in_git_work_tree?() and not gitignored?(relative) do
      Mix.shell().info("""
      warning: #{relative}/ is not in .gitignore.
        Recommended: add the following line so generated artifacts don't end
        up committed:

            /#{relative}/
      """)
    end

    :ok
  end

  defp in_git_work_tree? do
    # Merge stderr into the captured output so "fatal: not a git
    # repository" doesn't leak to the user's terminal.
    case System.cmd("git", ["rev-parse", "--is-inside-work-tree"], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output) == "true"
      _ -> false
    end
  rescue
    ErlangError -> false
  end

  defp gitignored?(path) do
    # Pass the path with a trailing slash so directory-style ignore
    # patterns (e.g. `/bin/`) match. check-ignore's exit code is the
    # source of truth: 0 = ignored, 1 = not ignored, anything else =
    # error (treat as not ignored).
    case System.cmd("git", ["check-ignore", "-q", path <> "/"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    ErlangError -> false
  end

  @doc """
  Warns if no plushie configuration is detected.

  Shows recommended config blocks for each environment.
  Only warns once per VM session.
  """
  @spec warn_if_unconfigured() :: :ok
  def warn_if_unconfigured do
    if Application.get_all_env(:plushie) == [] and
         not :persistent_term.get(:plushie_config_warned, false) do
      :persistent_term.put(:plushie_config_warned, true)

      Mix.shell().info("""

      No plushie configuration detected. Recommended setup:

          # config/dev.exs
          config :plushie,
            code_reloader: true

          # config/test.exs
          config :plushie,
            test_backend: :mock

          # config/prod.exs
          config :plushie,
            build_profile: :release
      """)
    end

    :ok
  end
end
