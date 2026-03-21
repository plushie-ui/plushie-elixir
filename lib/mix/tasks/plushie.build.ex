defmodule Mix.Tasks.Plushie.Build do
  @min_rust_version {1, 92, 0}

  @moduledoc """
  Build the plushie binary from source, optionally with widget extensions.

  Without extensions configured, builds the stock plushie binary from the Rust
  source checkout. With extensions, generates a custom Cargo workspace that
  registers each extension crate and builds a combined binary.

  ## Prerequisites

  - **Rust toolchain** #{elem(@min_rust_version, 0)}.#{elem(@min_rust_version, 1)}+ (install via https://rustup.rs)
  - **Plushie Rust source** -- set `PLUSHIE_SOURCE_PATH` or `config :plushie, :source_path`

  ## Usage

      mix plushie.build              # debug build
      mix plushie.build --release    # optimized release build
      mix plushie.build --verbose    # print cargo output on success

  ## Options

  - `--release` -- Build with optimizations (also implied by `MIX_ENV=prod`)
  - `--verbose` -- Print full cargo output on successful builds

  ## Extensions

  Register extensions in your config to build a custom binary:

      config :plushie, extensions: [MyApp.SparklineExtension]

  The task validates that each module implements the `Plushie.Extension`
  behaviour and that no two extensions claim the same widget type name.
  A Cargo workspace is generated under the Mix build directory with a
  `main.rs` that registers all extensions.

  The built binary is installed to `priv/bin/` for runtime resolution.
  """
  @shortdoc "Build the plushie binary"

  use Mix.Task

  @impl true
  def run(args) do
    check_rust_toolchain()

    # Ensure the project is compiled so extension modules are available
    Mix.Task.run("compile", [])

    extensions = configured_extensions()

    if extensions == [] do
      build_stock(args)
    else
      check_collisions!(extensions)
      check_crate_name_collisions!(extensions)
      build_with_extensions(extensions, args)
    end
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

  defp build_stock(args) do
    source_dir = Mix.PlushieHelpers.source_path!()

    unless File.dir?(source_dir) do
      Mix.raise("""
      plushie source not found at #{source_dir}.

      Check that PLUSHIE_SOURCE_PATH or config :plushie, :source_path
      points to a valid checkout of the plushie repo.
      """)
    end

    release? = "--release" in args

    cmd_args = ["build", "-p", "plushie"]
    cmd_args = if release?, do: cmd_args ++ ["--release"], else: cmd_args

    Mix.shell().info("Building plushie#{if release?, do: " (release)", else: ""}...")

    case System.cmd("cargo", cmd_args, stderr_to_stdout: true, cd: source_dir) do
      {output, 0} ->
        Mix.shell().info("Build succeeded.")
        if "--verbose" in args, do: Mix.shell().info(output)
        install_binary(source_dir, release?)

      {output, status} ->
        Mix.shell().error("Build failed (exit code #{status}):")
        Mix.shell().error(output)
        Mix.raise("cargo build failed")
    end
  end

  # Copy the built binary into priv/bin/ so the resolution chain finds it
  # without needing PLUSHIE_BINARY_PATH or PLUSHIE_SOURCE_PATH at runtime.
  defp install_binary(source_dir, release?) do
    profile = if release?, do: "release", else: "debug"
    src = Path.join([source_dir, "target", profile, "plushie"])

    unless File.exists?(src) do
      Mix.raise("Build succeeded but binary not found at #{src}")
    end

    dest_dir = Path.join(["priv", "bin"])
    dest = Path.join(dest_dir, Plushie.Binary.download_name())

    File.mkdir_p!(dest_dir)
    File.cp!(src, dest)
    File.chmod!(dest, 0o755)

    Mix.shell().info("Installed to #{dest}")
  end

  # Copy an extension binary into priv/bin/ so the resolution chain finds it
  # at runtime. Uses the platform download name so `Plushie.Binary.path!/0`
  # resolves it the same way it resolves the stock binary.
  defp install_extension_binary(src) do
    unless File.exists?(src) do
      Mix.raise("Build succeeded but binary not found at #{src}")
    end

    dest_dir = Path.join(["priv", "bin"])
    dest = Path.join(dest_dir, Plushie.Binary.download_name())

    File.mkdir_p!(dest_dir)
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

  defp build_with_extensions(extensions, args) do
    build_dir = Path.join(Mix.Project.build_path(), "plushie")
    File.mkdir_p!(build_dir)

    bin_name = Plushie.Binary.build_name()
    crate_paths = resolve_crate_paths(extensions)
    generate_workspace(build_dir, bin_name, extensions, crate_paths)

    ext_names = Enum.map_join(extensions, ", ", &inspect/1)

    Mix.shell().info(
      "Generated custom build workspace at #{build_dir} " <>
        "with #{length(extensions)} extension(s): #{ext_names}"
    )

    release? = "--release" in args or Mix.env() == :prod
    release_flags = if release?, do: ["--release"], else: []
    profile = if release?, do: "release", else: "debug"

    Mix.shell().info("Building #{bin_name}#{if release?, do: " (release)", else: ""}...")

    case System.cmd("cargo", ["build"] ++ release_flags,
           cd: build_dir,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        Mix.shell().info("Build succeeded.")
        if "--verbose" in args, do: Mix.shell().info(output)
        binary = Path.join([build_dir, "target", profile, bin_name])
        Mix.shell().info("Binary: #{binary}")
        install_extension_binary(binary)
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

    # Use local source paths if available, otherwise pull from crates.io
    {plushie_core_dep, plushie_bin_dep} =
      if source_path && File.dir?(source_path) do
        plushie_core_rel = Path.relative_to(Path.join(source_path, "plushie-core"), build_dir)
        plushie_bin_rel = Path.relative_to(Path.join(source_path, "plushie"), build_dir)

        {~s(plushie-core = { path = "#{plushie_core_rel}" }),
         ~s(plushie = { path = "#{plushie_bin_rel}" })}
      else
        {~s(plushie-core = "#{@binary_version}"), ~s(plushie = "#{@binary_version}")}
      end

    ext_deps =
      Enum.map_join(extensions, "\n", fn mod ->
        path = crate_paths[mod]
        rel_path = Path.relative_to(path, build_dir)
        crate_name = Path.basename(path)
        "#{crate_name} = { path = \"#{rel_path}\" }"
      end)

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
    #{plushie_core_dep}
    #{plushie_bin_dep}
    #{ext_deps}
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

    use plushie_core::app::PlushieAppBuilder;

    fn main() -> iced::Result {
        let builder = PlushieAppBuilder::new()
                #{ext_registrations};
        plushie::run(builder)
    }
    """
  end
end
