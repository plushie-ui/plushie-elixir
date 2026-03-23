defmodule Mix.Tasks.Plushie.Build do
  @min_rust_version {1, 92, 0}

  @moduledoc """
  Build the plushie binary and/or WASM renderer from source.

  Without extensions configured, builds the stock plushie binary from the Rust
  source checkout. With extensions, generates a custom Cargo workspace that
  registers each extension crate and builds a combined binary.

  ## Prerequisites

  - **Rust toolchain** #{elem(@min_rust_version, 0)}.#{elem(@min_rust_version, 1)}+ (install via https://rustup.rs)
  - **Plushie Rust source** -- set `PLUSHIE_SOURCE_PATH` or `config :plushie, :source_path`
  - **wasm-pack** (for `--wasm` only) -- install via https://rustwasm.github.io/wasm-pack/

  ## Usage

      mix plushie.build              # build native binary (default)
      mix plushie.build --release    # optimized release build
      mix plushie.build --wasm       # build WASM renderer only
      mix plushie.build --bin --wasm # build both
      mix plushie.build --verbose    # print cargo output on success

  ## Options

  - `--bin` -- Build the native binary
  - `--wasm` -- Build the WASM renderer via wasm-pack
  - `--bin-file PATH` -- Override native binary destination
  - `--wasm-dir PATH` -- Override WASM output directory
  - `--release` -- Build with optimizations (also implied by `MIX_ENV=prod`)
  - `--verbose` -- Print full cargo output on successful builds

  ## Config

  Artifact selection and output paths can be set in `config.exs`:

      config :plushie,
        artifacts: [:bin, :wasm],       # which artifacts to build
        bin_file: "priv/bin/plushie-renderer",  # binary destination
        wasm_dir: "priv/static"         # WASM output directory

  CLI flags override config. Default artifacts: `[:bin]`.

  ## Extensions

  Register extensions in your config to build a custom binary:

      config :plushie, extensions: [MyApp.SparklineExtension]

  The task validates that each module implements the `Plushie.Extension`
  behaviour and that no two extensions claim the same widget type name.
  A Cargo workspace is generated under the Mix build directory with a
  `main.rs` that registers all extensions.
  """
  @shortdoc "Build the plushie binary and/or WASM"

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _rest} =
      OptionParser.parse!(args,
        strict: [
          bin: :boolean,
          wasm: :boolean,
          release: :boolean,
          verbose: :boolean,
          bin_file: :string,
          wasm_dir: :string
        ]
      )

    {want_bin?, want_wasm?} = Mix.PlushieHelpers.resolve_artifacts(opts)
    release? = opts[:release] || false
    verbose? = opts[:verbose] || false

    if want_bin?, do: build_bin(release?, verbose?, opts)
    if want_wasm?, do: build_wasm(release?, verbose?, opts)
  end

  defp build_bin(release?, verbose?, opts) do
    check_rust_toolchain()

    # Ensure the project is compiled so extension modules are available
    Mix.Task.run("compile", [])

    extensions = configured_extensions()

    if extensions == [] do
      build_stock(release?, verbose?, opts)
    else
      check_collisions!(extensions)
      check_crate_name_collisions!(extensions)
      build_with_extensions(extensions, release?, verbose?, opts)
    end
  end

  defp build_wasm(release?, verbose?, opts) do
    check_wasm_pack()

    source_dir = Mix.PlushieHelpers.source_path!()

    wasm_crate = Path.join(source_dir, "plushie-renderer-wasm")

    unless File.dir?(wasm_crate) do
      Mix.raise("""
      plushie-renderer-wasm crate not found at #{wasm_crate}.

      The WASM build requires the plushie-renderer source checkout.
      """)
    end

    release? = release? or Mix.env() == :prod
    profile = if release?, do: "--release", else: "--dev"

    Mix.shell().info("Building plushie-wasm#{if release?, do: " (release)", else: ""}...")

    # Disable externref to avoid "failed to grow table" errors in browsers
    # that don't fully support the reference types proposal.
    env = [{"WASM_BINDGEN_EXTERNREF", "0"}]

    case System.cmd("wasm-pack", ["build", "--target", "web", profile],
           cd: wasm_crate,
           stderr_to_stdout: true,
           env: env
         ) do
      {output, 0} ->
        Mix.shell().info("WASM build succeeded.")
        if verbose?, do: Mix.shell().info(output)
        install_wasm(wasm_crate, opts)

      {output, status} ->
        Mix.shell().error("WASM build failed (exit code #{status}):")
        Mix.shell().error(output)
        Mix.raise("wasm-pack build failed")
    end
  end

  defp install_wasm(wasm_crate, opts) do
    pkg_dir = Path.join(wasm_crate, "pkg")
    dest_dir = Mix.PlushieHelpers.resolve_wasm_dir(opts)
    File.mkdir_p!(dest_dir)

    for name <- ["plushie_renderer_wasm.js", "plushie_renderer_wasm_bg.wasm"] do
      src = Path.join(pkg_dir, name)

      if File.exists?(src) do
        File.cp!(src, Path.join(dest_dir, name))
      else
        Mix.shell().error("Warning: expected #{src} not found in wasm-pack output")
      end
    end

    Mix.shell().info("Installed WASM files to #{dest_dir}")
  end

  defp check_wasm_pack do
    case System.cmd("wasm-pack", ["--version"], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      _ -> Mix.raise("wasm-pack not found. Install via https://rustwasm.github.io/wasm-pack/")
    end
  rescue
    ErlangError ->
      Mix.raise("wasm-pack not found. Install via https://rustwasm.github.io/wasm-pack/")
  end

  defp check_rust_toolchain do
    {min_major, min_minor, min_patch} = @min_rust_version
    min_str = "#{min_major}.#{min_minor}.#{min_patch}"

    case System.cmd("rustc", ["--version"], stderr_to_stdout: true) do
      {output, 0} ->
        case Regex.run(~r/rustc (\d+)\.(\d+)\.(\d+)/, output) do
          [_, major, minor, patch] ->
            version =
              {String.to_integer(major), String.to_integer(minor), String.to_integer(patch)}

            if version < @min_rust_version do
              Mix.shell().info(
                "Warning: rustc #{major}.#{minor}.#{patch} detected, " <>
                  "but plushie requires >= #{min_str}. " <>
                  "Consider upgrading with `rustup update`."
              )
            end

          _ ->
            Mix.shell().info(
              "Warning: could not parse rustc version from: #{String.trim(output)}"
            )
        end

      {_, _} ->
        Mix.raise("rustc not found. Install Rust #{min_str}+ via https://rustup.rs")
    end
  rescue
    ErlangError ->
      {min_major, min_minor, min_patch} = @min_rust_version
      min_str = "#{min_major}.#{min_minor}.#{min_patch}"

      Mix.raise("rustc not found. Install Rust #{min_str}+ via https://rustup.rs")
  end

  defp build_stock(release?, verbose?, opts) do
    source_dir = Mix.PlushieHelpers.source_path!()

    unless File.dir?(source_dir) do
      Mix.raise("""
      plushie source not found at #{source_dir}.

      Check that PLUSHIE_SOURCE_PATH or config :plushie, :source_path
      points to a valid checkout of the plushie repo.
      """)
    end

    release? = release? or Mix.env() == :prod

    cmd_args = ["build", "-p", "plushie-renderer"]
    cmd_args = if release?, do: cmd_args ++ ["--release"], else: cmd_args

    Mix.shell().info("Building plushie#{if release?, do: " (release)", else: ""}...")

    case System.cmd("cargo", cmd_args, stderr_to_stdout: true, cd: source_dir) do
      {output, 0} ->
        Mix.shell().info("Build succeeded.")
        if verbose?, do: Mix.shell().info(output)
        install_binary(source_dir, release?, opts)

      {output, status} ->
        Mix.shell().error("Build failed (exit code #{status}):")
        Mix.shell().error(output)
        Mix.raise("cargo build failed")
    end
  end

  # Copy the built binary into _build/plushie/bin/ so the resolution chain
  # finds it without needing PLUSHIE_BINARY_PATH or PLUSHIE_SOURCE_PATH.
  defp install_binary(source_dir, release?, opts) do
    profile = if release?, do: "release", else: "debug"
    src = Path.join([source_dir, "target", profile, "plushie-renderer"])

    unless File.exists?(src) do
      Mix.raise("Build succeeded but binary not found at #{src}")
    end

    install_bin_to(src, opts)
  end

  defp install_extension_binary(src, opts) do
    unless File.exists?(src) do
      Mix.raise("Build succeeded but binary not found at #{src}")
    end

    install_bin_to(src, opts)
  end

  defp install_bin_to(src, opts) do
    dest = Mix.PlushieHelpers.resolve_bin_file(opts)
    File.mkdir_p!(Path.dirname(dest))
    File.cp!(src, dest)
    File.chmod!(dest, 0o755)
    Mix.shell().info("Installed to #{dest}")
  end

  # -- Extension registration -------------------------------------------------

  @doc """
  Returns the list of extension modules from application config.

  Users register extensions explicitly in their config.exs:

      config :plushie, extensions: [MyApp.SparklineExtension]

  This replaces the previous `:code.all_loaded/0` auto-discovery approach,
  which was unreliable because it only saw modules already loaded by the VM
  at the time of the call.
  """
  @spec configured_extensions() :: [module()]
  def configured_extensions do
    extensions = Application.get_env(:plushie, :extensions, [])

    unless is_list(extensions) do
      Mix.raise("""
      Invalid :extensions config for :plushie.

      Expected a list of modules, got: #{inspect(extensions)}

      Configure in config.exs:
          config :plushie, extensions: [MyApp.SparklineExtension]
      """)
    end

    # Validate that each module implements the Plushie.Extension behaviour.
    Enum.each(extensions, fn mod ->
      unless Code.ensure_loaded?(mod) do
        Mix.raise("Extension module #{inspect(mod)} could not be loaded")
      end

      behaviours = mod_behaviours(mod)

      unless Plushie.Extension in behaviours do
        Mix.raise(
          "Module #{inspect(mod)} is listed in :plushie :extensions config " <>
            "but does not implement the Plushie.Extension behaviour"
        )
      end
    end)

    extensions
  end

  defp mod_behaviours(mod) do
    if function_exported?(mod, :module_info, 1) do
      (mod.module_info(:attributes)[:behaviour] || []) ++
        (mod.module_info(:attributes)[:behavior] || [])
    else
      []
    end
  end

  # -- Collision detection ----------------------------------------------------

  @doc """
  Raises `Mix.Error` if any two extensions claim the same type name.
  """
  @spec check_collisions!(extensions :: [module()]) :: :ok
  def check_collisions!(extensions) do
    all_types =
      Enum.flat_map(extensions, fn mod ->
        Enum.map(mod.type_names(), &{&1, mod})
      end)

    duplicates =
      all_types
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_type, mods} -> length(mods) > 1 end)

    if duplicates != [] do
      messages =
        Enum.map(duplicates, fn {type, mods} ->
          mod_names = Enum.map_join(mods, ", ", &inspect/1)
          "  #{type}: #{mod_names}"
        end)

      Mix.raise("""
      Extension type name collision detected:
      #{Enum.join(messages, "\n")}

      Each type name must be handled by exactly one extension.\
      """)
    end

    :ok
  end

  @doc """
  Raises `Mix.Error` if any two extensions produce the same Cargo crate name.

  The crate name is `Path.basename/1` of each extension's `native_crate/0`
  path. Two extensions at `native/widget/` and `other/widget/` would both
  produce `widget`, causing a Cargo dependency conflict.
  """
  @spec check_crate_name_collisions!(extensions :: [module()]) :: :ok
  def check_crate_name_collisions!(extensions) do
    all_crates =
      Enum.map(extensions, fn mod ->
        crate_name = Path.basename(mod.native_crate())
        {crate_name, mod}
      end)

    duplicates =
      all_crates
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_name, mods} -> length(mods) > 1 end)

    if duplicates != [] do
      messages =
        Enum.map(duplicates, fn {name, mods} ->
          mod_names = Enum.map_join(mods, ", ", &inspect/1)
          "  #{name}: #{mod_names}"
        end)

      Mix.raise("""
      Extension crate name collision detected:
      #{Enum.join(messages, "\n")}

      Each extension's native_crate path must have a unique basename.
      Rename one of the crate directories to resolve the conflict.\
      """)
    end

    :ok
  end

  # -- Extension build --------------------------------------------------------

  defp build_with_extensions(extensions, release?, verbose?, opts) do
    build_dir = Path.join(Mix.Project.build_path(), "plushie-renderer")
    File.mkdir_p!(build_dir)

    bin_name = Plushie.Binary.build_name()
    crate_paths = resolve_crate_paths(extensions)
    generate_workspace(build_dir, bin_name, extensions, crate_paths)

    ext_names = Enum.map_join(extensions, ", ", &inspect/1)

    Mix.shell().info(
      "Generated custom build workspace at #{build_dir} " <>
        "with #{length(extensions)} extension(s): #{ext_names}"
    )

    release? = release? or Mix.env() == :prod
    release_flags = if release?, do: ["--release"], else: []
    profile = if release?, do: "release", else: "debug"

    Mix.shell().info("Building #{bin_name}#{if release?, do: " (release)", else: ""}...")

    case System.cmd("cargo", ["build"] ++ release_flags,
           cd: build_dir,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        Mix.shell().info("Build succeeded.")
        if verbose?, do: Mix.shell().info(output)
        binary = Path.join([build_dir, "target", profile, bin_name])
        Mix.shell().info("Binary: #{binary}")
        install_extension_binary(binary, opts)
        :ok

      {output, status} ->
        Mix.shell().error("Build failed (exit code #{status}):")
        Mix.shell().error(output)
        Mix.raise("cargo build failed for custom build workspace")
    end
  end

  defp resolve_crate_paths(extensions) do
    deps_paths = Mix.Project.deps_paths()

    Map.new(extensions, fn mod ->
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

      unless String.starts_with?(resolved, allowed_root) do
        Mix.raise(
          "Extension #{inspect(mod)} native_crate path #{inspect(crate_rel)} " <>
            "resolves to #{resolved}, which is outside the allowed directory #{allowed_root}"
        )
      end

      {mod, resolved}
    end)
  end

  defp generate_workspace(build_dir, bin_name, extensions, crate_paths) do
    cargo_toml = generate_cargo_toml(bin_name, extensions, crate_paths, build_dir)
    File.write!(Path.join(build_dir, "Cargo.toml"), cargo_toml)

    src_dir = Path.join(build_dir, "src")
    File.mkdir_p!(src_dir)
    main_rs = generate_main_rs(extensions)
    File.write!(Path.join(src_dir, "main.rs"), main_rs)
  end

  @binary_version Mix.Project.config()[:binary_version] ||
                    raise("missing :binary_version in project config (mix.exs)")

  defp generate_cargo_toml(bin_name, extensions, crate_paths, build_dir) do
    source_path = Mix.PlushieHelpers.source_path()

    # Use local source paths if available, otherwise pull from crates.io.
    # The plushie-renderer workspace has two crates the extension needs:
    #   plushie-ext       -- core library (widget types, protocols, extensions API)
    #   plushie-renderer  -- binary entry point (run function)
    {plushie_ext_dep, plushie_renderer_dep} =
      if source_path && File.dir?(source_path) do
        ext_rel = Path.relative_to(Path.join(source_path, "plushie-ext"), build_dir)
        renderer_rel = Path.relative_to(Path.join(source_path, "plushie-renderer"), build_dir)

        {~s(plushie-ext = { path = "#{ext_rel}" }),
         ~s(plushie-renderer = { path = "#{renderer_rel}" })}
      else
        {~s(plushie-ext = "#{@binary_version}"), ~s(plushie-renderer = "#{@binary_version}")}
      end

    ext_deps =
      Enum.map_join(extensions, "\n", fn mod ->
        path = crate_paths[mod]
        rel_path = Path.relative_to(path, build_dir)
        crate_name = Path.basename(path)
        "#{crate_name} = { path = \"#{rel_path}\" }"
      end)

    # When using local source paths, add [patch.crates-io] so extension
    # crates that depend on plushie-ext from crates.io get redirected to
    # the same local checkout. Without this, Cargo treats the path dep and
    # the crates.io dep as different crates and trait impls don't match.
    patch_section =
      if source_path && File.dir?(source_path) do
        ext_path = Path.join(source_path, "plushie-ext")
        renderer_path = Path.join(source_path, "plushie-renderer")

        """

        [patch.crates-io]
        plushie-ext = { path = "#{ext_path}" }
        plushie-renderer = { path = "#{renderer_path}" }
        """
      else
        ""
      end

    # Use underscores for the Cargo package name (Cargo convention)
    package_name = String.replace(bin_name, "-", "_")

    """
    [package]
    name = "#{package_name}"
    version = "#{Mix.Project.config()[:version]}"
    edition = "2024"

    [[bin]]
    name = "#{bin_name}"
    path = "src/main.rs"

    [dependencies]
    #{plushie_ext_dep}
    #{plushie_renderer_dep}
    #{ext_deps}
    #{patch_section}\
    """
  end

  @rust_constructor_pattern ~r/^[A-Za-z_][A-Za-z0-9_:]*(\([^)]*\))?$/

  defp validate_rust_constructor!(mod, constructor) do
    unless Regex.match?(@rust_constructor_pattern, constructor) do
      Mix.raise(
        "Extension #{inspect(mod)} rust_constructor #{inspect(constructor)} " <>
          "contains invalid characters. Expected a Rust identifier, path (::), " <>
          "or simple invocation (e.g. \"MyExt::new()\")"
      )
    end
  end

  defp generate_main_rs(extensions) do
    ext_registrations =
      Enum.map_join(extensions, "\n        ", fn mod ->
        constructor = mod.rust_constructor()
        validate_rust_constructor!(mod, constructor)
        ".extension(#{constructor})"
      end)

    """
    // Auto-generated by mix plushie.build
    // Do not edit manually.

    use plushie_ext::app::PlushieAppBuilder;

    fn main() -> plushie_ext::iced::Result {
        let builder = PlushieAppBuilder::new()
                #{ext_registrations};
        plushie_renderer::run(builder)
    }
    """
  end
end
