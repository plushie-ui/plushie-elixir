defmodule Mix.Tasks.Plushie.Build do
  @min_rust_version {1, 92, 0}

  @moduledoc """
  Build the plushie renderer binary and/or WASM renderer from source.

  Delegates the heavy lifting to the `cargo-plushie` Cargo subcommand:
  this task discovers the project's native widgets, writes a small
  "renderer spec" Cargo.toml into `_build/<env>/plushie-renderer-spec/`,
  and then shells out to `cargo plushie build` against that manifest.
  cargo-plushie handles widget collision checks, workspace generation,
  and the final cargo invocation.

  When a local source checkout is available (`PLUSHIE_RUST_SOURCE_PATH`),
  the spec is built against local path dependencies; otherwise cargo-plushie
  resolves plushie crates from crates.io using `PLUSHIE_RUST_VERSION`.

  ## Prerequisites

  - **Rust toolchain** #{elem(@min_rust_version, 0)}.#{elem(@min_rust_version, 1)}+ (install via https://rustup.rs)
  - **cargo-plushie** on PATH, or `PLUSHIE_RUST_SOURCE_PATH` pointing at a
    local plushie-rust checkout for development.
  - **wasm-pack** (for `--wasm` only): install via https://rustwasm.github.io/wasm-pack/

  ## Usage

      mix plushie.build              # build native binary (default)
      mix plushie.build --release    # optimized release build
      mix plushie.build --wasm       # build WASM renderer only
      mix plushie.build --bin --wasm # build both
      mix plushie.build --verbose    # print cargo output on success

  ## Options

  - `--bin`: Build the native binary
  - `--wasm`: Build the WASM renderer via wasm-pack
  - `--bin-file PATH`: Override native binary destination
  - `--wasm-dir PATH`: Override WASM output directory
  - `--release`: Build with optimizations (also implied by `MIX_ENV=prod`)
  - `--verbose`: Print full cargo output on successful builds
  - `--update`: Force a clean rebuild by wiping the spec scratch directory

  ## Config

  Artifact selection and output paths can be set in `config.exs`:

      config :plushie,
        artifacts: [:bin, :wasm],       # which artifacts to build
        bin_file: "priv/bin/plushie-renderer",  # binary destination
        wasm_dir: "priv/static"         # WASM output directory

  CLI flags override config. Default artifacts: `[:bin]`.

  ## Native widgets

  Native widgets are auto-detected via the `Plushie.Widget` protocol.
  Any module implementing the protocol and exporting `native_crate/0`
  is listed as a path dependency in the generated spec. cargo-plushie
  reads `[package.metadata.plushie.widget]` from each widget's own
  `Cargo.toml` to derive the type name and constructor expression.
  """
  @shortdoc "Build the plushie renderer binary and/or WASM"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _rest} =
      OptionParser.parse!(args,
        strict: [
          bin: :boolean,
          wasm: :boolean,
          release: :boolean,
          verbose: :boolean,
          update: :boolean,
          bin_file: :string,
          wasm_dir: :string
        ]
      )

    Mix.PlushieHelpers.warn_if_unconfigured()
    {want_bin?, want_wasm?} = Mix.PlushieHelpers.resolve_artifacts(opts)
    release? = opts[:release] || Application.get_env(:plushie, :build_profile) == :release
    verbose? = opts[:verbose] || false
    update? = opts[:update] || false

    if want_bin?, do: build_bin(release?, verbose?, update?, opts)
    if want_wasm?, do: build_wasm(release?, verbose?, opts)
  end

  # -- Native binary ---------------------------------------------------------

  defp build_bin(release?, verbose?, update?, opts) do
    check_rust_toolchain()
    check_cargo()

    # Ensure the project is compiled so widget modules are available
    # for protocol-based discovery.
    Mix.PlushieHelpers.compile_project!()

    native = Plushie.WidgetRegistry.native_widgets()
    bin_name = binary_name_for(native)

    spec_dir = spec_dir()

    if update? and File.dir?(spec_dir) do
      File.rm_rf!(spec_dir)
    end

    File.mkdir_p!(spec_dir)

    crate_paths = resolve_crate_paths(native)
    write_spec_cargo_toml!(spec_dir, bin_name, native, crate_paths)

    source_info =
      case Mix.PlushieHelpers.source_path() do
        nil -> "crates.io v#{Plushie.Binary.plushie_rust_version()}"
        _ -> "local source"
      end

    if native != [] do
      widget_names = Enum.map_join(native, ", ", &inspect/1)
      Mix.shell().info("Native widgets: #{widget_names}")
    end

    Mix.shell().info("Source: #{source_info}")
    Mix.shell().info("Building #{bin_name}#{if release?, do: " (release)", else: ""}...")

    invoke_cargo_plushie_build!(spec_dir, release?, verbose?)

    profile = if release?, do: "release", else: "debug"
    ext = if :os.type() |> elem(0) == :win32, do: ".exe", else: ""

    binary =
      Path.join([spec_dir, "target", "plushie-renderer", "target", profile, bin_name <> ext])

    install_bin_to(binary, opts)
  end

  # -- WASM ------------------------------------------------------------------

  defp build_wasm(release?, verbose?, opts) do
    check_cargo()

    Mix.PlushieHelpers.compile_project!()

    # cargo-plushie's --wasm path needs a plushie-rust checkout. Error
    # out early with the same guidance the user would hit later.
    unless Mix.PlushieHelpers.source_path() do
      Mix.raise("""
      WASM builds require PLUSHIE_RUST_SOURCE_PATH (or `config :plushie, :source_path`)
      to point at a local plushie-rust checkout. The WASM renderer has no published
      pre-built bundle to pull from crates.io.
      """)
    end

    spec_dir = spec_dir()
    File.mkdir_p!(spec_dir)
    write_spec_cargo_toml!(spec_dir, binary_name_for([]), [], %{})

    Mix.shell().info("Building plushie-wasm#{if release?, do: " (release)", else: ""}...")

    wasm_dir = Mix.PlushieHelpers.resolve_wasm_dir(opts)
    File.mkdir_p!(wasm_dir)

    invoke_cargo_plushie_wasm!(spec_dir, release?, verbose?, wasm_dir)
    Mix.shell().info("Installed WASM files to #{wasm_dir}")
  end

  # -- cargo-plushie shell-out ----------------------------------------------

  defp invoke_cargo_plushie_build!(spec_dir, release?, verbose?) do
    {cmd, prefix} = Mix.PlushieHelpers.resolve_cargo_plushie()

    manifest = Path.join(spec_dir, "Cargo.toml")
    args = prefix ++ ["build", "--manifest-path", manifest]
    args = if release?, do: args ++ ["--release"], else: args
    args = if verbose?, do: args ++ ["--verbose"], else: args

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info("Build succeeded.")
        if verbose?, do: Mix.shell().info(output)
        :ok

      {output, status} ->
        Mix.shell().error("Build failed (exit code #{status}):")
        Mix.shell().error(output)
        Mix.raise("cargo plushie build failed")
    end
  end

  defp invoke_cargo_plushie_wasm!(spec_dir, release?, verbose?, wasm_dir) do
    {cmd, prefix} = Mix.PlushieHelpers.resolve_cargo_plushie()

    manifest = Path.join(spec_dir, "Cargo.toml")
    args = prefix ++ ["build", "--manifest-path", manifest, "--wasm", "--wasm-dir", wasm_dir]
    args = if release?, do: args ++ ["--release"], else: args
    args = if verbose?, do: args ++ ["--verbose"], else: args

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info("WASM build succeeded.")
        if verbose?, do: Mix.shell().info(output)
        :ok

      {output, status} ->
        Mix.shell().error("WASM build failed (exit code #{status}):")
        Mix.shell().error(output)
        Mix.raise("cargo plushie build --wasm failed")
    end
  end

  # -- Renderer-spec Cargo.toml --------------------------------------------

  defp spec_dir do
    Path.join(Mix.Project.build_path(), "plushie-renderer-spec")
  end

  # Write the virtual-app Cargo.toml that cargo-plushie inspects via
  # `cargo metadata`. The file itself doesn't get built: cargo-plushie
  # uses it to discover widget crates and emits a separate renderer
  # workspace under `target/plushie-renderer/` to compile.
  defp write_spec_cargo_toml!(spec_dir, bin_name, widgets, crate_paths) do
    deps =
      Enum.map_join(widgets, "\n", fn mod ->
        path = crate_paths[mod]
        crate_basename = Path.basename(path)
        ~s(#{toml_string(crate_basename)} = { path = #{toml_string(path)} })
      end)

    deps_block = if deps == "", do: "", else: deps <> "\n"

    source_line =
      case Mix.PlushieHelpers.source_path() do
        nil ->
          ""

        source ->
          abs = Path.expand(source)
          "source_path = #{toml_string(abs)}\n"
      end

    package_name = "#{bin_name}-spec"
    version = Plushie.Binary.plushie_rust_version()

    content =
      """
      # Auto-generated by `mix plushie.build`. Do not edit.
      #
      # This manifest exists so `cargo plushie build` can discover the
      # app's native widget crates through `cargo metadata`. The actual
      # renderer workspace is emitted by cargo-plushie into
      # `target/plushie-renderer/`.

      [package]
      name = #{toml_string(package_name)}
      version = #{toml_string(version)}
      edition = "2024"
      publish = false

      [dependencies]
      #{deps_block}
      [package.metadata.plushie]
      binary_name = #{toml_string(bin_name)}
      #{source_line}\
      """
      |> String.trim_trailing()
      |> Kernel.<>("\n")

    # Minimal lib.rs so `cargo metadata` is happy without needing a bin.
    src_dir = Path.join(spec_dir, "src")
    File.mkdir_p!(src_dir)
    write_if_changed(Path.join(src_dir, "lib.rs"), "// Renderer spec placeholder.\n")
    write_if_changed(Path.join(spec_dir, "Cargo.toml"), content)
  end

  # Writes content to path only if it differs from the existing file.
  # Avoids mtime changes on identical content so downstream tools skip
  # regeneration work.
  defp write_if_changed(path, content) do
    if File.read(path) == {:ok, content} do
      :ok
    else
      File.write!(path, content)
    end
  end

  @spec toml_string(String.t()) :: String.t()
  defp toml_string(value), do: Jason.encode!(value)

  # -- Widget crate paths ---------------------------------------------------

  defp resolve_crate_paths(widgets) do
    deps_paths = Mix.Project.deps_paths()

    Map.new(widgets, fn mod ->
      app = Application.get_application(mod)
      crate_rel = mod.native_crate()

      base =
        if app && Map.has_key?(deps_paths, app) do
          deps_paths[app]
        else
          File.cwd!()
        end

      resolved = Path.expand(Path.join(base, crate_rel))
      allowed_root = Path.expand(base)

      unless resolved == allowed_root or String.starts_with?(resolved, allowed_root <> "/") do
        Mix.raise(
          "Widget #{inspect(mod)} native_crate path #{inspect(crate_rel)} " <>
            "resolves to #{resolved}, which is outside the allowed directory #{allowed_root}"
        )
      end

      unless File.dir?(resolved) do
        Mix.raise(
          "Widget #{inspect(mod)} native_crate path #{inspect(crate_rel)} " <>
            "resolves to #{resolved}, which does not exist. " <>
            "Ensure the crate directory is present and included in the package files."
        )
      end

      {mod, resolved}
    end)
  end

  # -- Binary name derivation -----------------------------------------------

  defp binary_name_for([]), do: "plushie-renderer"
  defp binary_name_for(_native), do: Plushie.Binary.build_name()

  # -- Install ---------------------------------------------------------------

  defp install_bin_to(src, opts) do
    unless File.exists?(src) do
      Mix.raise("Build succeeded but binary not found at #{src}")
    end

    dest = Mix.PlushieHelpers.resolve_bin_file(opts)
    File.mkdir_p!(Path.dirname(dest))
    File.cp!(src, dest)
    File.chmod!(dest, 0o755)
    Mix.shell().info("Installed to #{dest}")
  end

  # -- Toolchain checks -----------------------------------------------------

  defp check_rust_toolchain do
    {min_major, min_minor, min_patch} = @min_rust_version
    min_str = "#{min_major}.#{min_minor}.#{min_patch}"

    executable = System.find_executable("rustc")

    unless executable do
      Mix.raise("rustc not found. Install Rust #{min_str}+ via https://rustup.rs")
    end

    case System.cmd(executable, ["--version"], stderr_to_stdout: true) do
      {output, 0} ->
        case Regex.run(~r/rustc (\d+)\.(\d+)\.(\d+)/, output) do
          [_, major, minor, patch] ->
            version =
              {String.to_integer(major), String.to_integer(minor), String.to_integer(patch)}

            if version < @min_rust_version do
              Mix.raise(
                "rustc #{major}.#{minor}.#{patch} is too old for plushie " <>
                  "(requires >= #{min_str}). Upgrade with: rustup update"
              )
            end

          _ ->
            Mix.shell().info(
              "Warning: could not parse rustc version from: #{String.trim(output)}"
            )
        end

      {output, status} ->
        Mix.raise("rustc --version failed (exit code #{status}): #{String.trim(output)}")
    end
  end

  defp check_cargo do
    unless System.find_executable("cargo") do
      Mix.raise("""
      cargo not found.

      Install the Rust toolchain via https://rustup.rs which includes cargo.
      """)
    end
  end
end
