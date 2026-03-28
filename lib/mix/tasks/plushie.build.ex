defmodule Mix.Tasks.Plushie.Build do
  @min_rust_version {1, 92, 0}

  @moduledoc """
  Build the plushie binary and/or WASM renderer from source.

  Generates a Cargo workspace and builds it. When a local source checkout
  is available (`PLUSHIE_SOURCE_PATH`), dependencies use local paths for
  development. Otherwise, dependencies are pulled from crates.io using
  the `:binary_version` from mix.exs.

  With extensions configured, the workspace includes each extension crate
  and the generated `main.rs` registers them at startup.

  ## Prerequisites

  - **Rust toolchain** #{elem(@min_rust_version, 0)}.#{elem(@min_rust_version, 1)}+ (install via https://rustup.rs)
  - **Plushie Rust source** (optional) -- set `PLUSHIE_SOURCE_PATH` or
    `config :plushie, :source_path` to use local sources instead of crates.io
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

  @binary_version Mix.Project.config()[:binary_version] ||
                    raise("missing :binary_version in project config (mix.exs)")

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
    check_cargo()

    # Ensure the project is compiled so extension modules are available
    Mix.Task.run("compile", [])

    all_extensions = configured_extensions()

    # Only native extensions (those with a Rust crate) need building.
    # Pure Elixir :widget extensions compose existing widgets and don't
    # require a custom binary.
    {native, skipped} =
      Enum.split_with(all_extensions, &function_exported?(&1, :native_crate, 0))

    if skipped != [] do
      names = Enum.map_join(skipped, ", ", &inspect/1)
      Mix.shell().info("Skipping non-native extension(s): #{names}")
    end

    if native != [] do
      check_collisions!(native)
      check_crate_name_collisions!(native)
    end

    build_workspace(native, release?, verbose?, opts)
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

  defp check_cargo do
    unless System.find_executable("cargo") do
      Mix.raise("""
      cargo not found.

      Install the Rust toolchain via https://rustup.rs which includes cargo.
      """)
    end
  end

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

  # -- Workspace build --------------------------------------------------------

  defp build_workspace(native_extensions, release?, verbose?, opts) do
    build_dir = Path.join(Mix.Project.build_path(), "plushie-renderer")
    File.mkdir_p!(build_dir)

    bin_name =
      if native_extensions == [],
        do: "plushie-renderer",
        else: Plushie.Binary.build_name()

    crate_paths = resolve_crate_paths(native_extensions)

    if crate_paths != %{} do
      check_extension_versions!(crate_paths)
    end

    generate_workspace(build_dir, bin_name, native_extensions, crate_paths)

    source_info =
      if Mix.PlushieHelpers.source_path(),
        do: "local source",
        else: "crates.io v#{@binary_version}"

    if native_extensions != [] do
      ext_names = Enum.map_join(native_extensions, ", ", &inspect/1)
      Mix.shell().info("Extensions: #{ext_names}")
    end

    Mix.shell().info("Source: #{source_info}")

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
        install_bin_to(binary, opts)

      {output, status} ->
        Mix.shell().error("Build failed (exit code #{status}):")
        Mix.shell().error(output)
        Mix.raise("cargo build failed")
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

  # ---------------------------------------------------------------------------
  # Extension version compatibility check
  #
  # Each extension crate should depend on a plushie-ext version compatible
  # with @binary_version. We check this before building to give a clear
  # error instead of a cryptic Cargo resolution failure.
  # ---------------------------------------------------------------------------

  defp check_extension_versions!(crate_paths) do
    expected = Version.parse!(@binary_version)

    Enum.each(crate_paths, fn {mod, crate_path} ->
      cargo_toml_path = Path.join(crate_path, "Cargo.toml")

      case read_plushie_ext_version(cargo_toml_path) do
        {:version, dep_version} ->
          check_version_compatible!(mod, dep_version, expected)

        {:path, dep_path} ->
          # Path dependency -- read the version from the target Cargo.toml.
          target_toml = Path.join(Path.expand(dep_path, crate_path), "Cargo.toml")

          case read_package_version(target_toml) do
            {:ok, pkg_version} -> check_version_compatible!(mod, pkg_version, expected)
            :error -> :ok
          end

        :not_found ->
          Mix.shell().info(
            "Extension #{inspect(mod)}: no plushie-ext dependency found in #{cargo_toml_path}"
          )

        :no_cargo_toml ->
          :ok
      end
    end)
  end

  defp check_version_compatible!(mod, dep_version_str, expected) do
    # Strip leading operators (^, ~, >=, =) to get the base version.
    base = String.replace(dep_version_str, ~r/^[^0-9]*/, "")

    case Version.parse(base) do
      {:ok, dep} ->
        # For pre-1.0 crates (0.x), major AND minor must match (Cargo semver).
        # For 1.0+, only major must match.
        compatible? = versions_compatible?(dep, expected)

        unless compatible? do
          Mix.shell().error(
            "Extension #{inspect(mod)} depends on plushie-ext #{dep_version_str}, " <>
              "but this project targets #{expected}. " <>
              "Update the extension crate or change :binary_version in mix.exs."
          )
        end

      :error ->
        :ok
    end
  end

  # Pre-1.0 (0.x): major AND minor must match. 1.0+: major must match.
  # Dialyzer sees @binary_version is 0.x at compile time and marks the
  # 1.0+ branch as unreachable. That branch is needed for when we ship 1.0.
  @dialyzer {:no_match, versions_compatible?: 2}
  defp versions_compatible?(dep, expected) do
    if expected.major == 0 do
      dep.major == expected.major and dep.minor == expected.minor
    else
      dep.major == expected.major
    end
  end

  # Read the plushie-ext dependency version from a Cargo.toml.
  # Returns {:version, "0.5.0"}, {:path, "../plushie-ext"}, or :not_found.
  defp read_plushie_ext_version(cargo_toml_path) do
    if File.exists?(cargo_toml_path) do
      content = File.read!(cargo_toml_path)

      cond do
        # Inline version: plushie-ext = "0.5.0"
        match = Regex.run(~r/plushie-ext\s*=\s*"([^"]+)"/, content) ->
          {:version, Enum.at(match, 1)}

        # Table with version: plushie-ext = { version = "0.5.0", ... }
        match = Regex.run(~r/plushie-ext\s*=\s*\{[^}]*version\s*=\s*"([^"]+)"/, content) ->
          {:version, Enum.at(match, 1)}

        # Table with path only: plushie-ext = { path = "..." }
        match = Regex.run(~r/plushie-ext\s*=\s*\{[^}]*path\s*=\s*"([^"]+)"/, content) ->
          {:path, Enum.at(match, 1)}

        true ->
          :not_found
      end
    else
      :no_cargo_toml
    end
  end

  # Read the [package] version from a Cargo.toml.
  defp read_package_version(cargo_toml_path) do
    if File.exists?(cargo_toml_path) do
      content = File.read!(cargo_toml_path)

      case Regex.run(~r/\[package\][^\[]*version\s*=\s*"([^"]+)"/s, content) do
        [_, version] -> {:ok, version}
        _ -> :error
      end
    else
      :error
    end
  end

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
      if extensions == [] do
        ""
      else
        "\n" <>
          Enum.map_join(extensions, "\n", fn mod ->
            path = crate_paths[mod]
            rel_path = Path.relative_to(path, build_dir)
            crate_name = Path.basename(path)
            "#{crate_name} = { path = \"#{rel_path}\" }"
          end)
      end

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

  # Validates Rust constructor expressions. Matches:
  #   gauge::GaugeExtension::new()      -- module path with call
  #   MyExt::<Config>::new()            -- turbofish generics
  #   MyExt::new                        -- path without parens
  #   create_widget()                   -- bare function call
  @rust_constructor_pattern ~r/^[A-Za-z_][A-Za-z0-9_:<>, ]*(\([^)]*\))?$/

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
    builder_expr =
      if extensions == [] do
        "PlushieAppBuilder::new()"
      else
        registrations =
          Enum.map_join(extensions, "\n        ", fn mod ->
            constructor = mod.rust_constructor()
            validate_rust_constructor!(mod, constructor)
            ".extension(#{constructor})"
          end)

        "PlushieAppBuilder::new()\n        #{registrations}"
      end

    """
    // Auto-generated by mix plushie.build
    // Do not edit manually.

    use plushie_ext::app::PlushieAppBuilder;

    fn main() -> plushie_ext::iced::Result {
        let builder = #{builder_expr};
        plushie_renderer::run(builder)
    }
    """
  end
end
