defmodule Mix.Tasks.Toddy.Build do
  @moduledoc "Build the toddy binary."
  @shortdoc "Build the toddy binary"

  use Mix.Task

  @min_rust_version {1, 92, 0}

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
                  "but toddy requires >= #{min_str}. " <>
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
    source_dir = Mix.ToddyHelpers.source_path!()

    unless File.dir?(source_dir) do
      Mix.raise("""
      toddy source not found at #{source_dir}.

      Check that TODDY_SOURCE_PATH or config :toddy, :source_path
      points to a valid checkout of the toddy repo.
      """)
    end

    release? = "--release" in args

    cmd_args = ["build", "-p", "toddy"]
    cmd_args = if release?, do: cmd_args ++ ["--release"], else: cmd_args

    Mix.shell().info("Building toddy#{if release?, do: " (release)", else: ""}...")

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
  # without needing TODDY_BINARY_PATH or TODDY_SOURCE_PATH at runtime.
  defp install_binary(source_dir, release?) do
    profile = if release?, do: "release", else: "debug"
    src = Path.join([source_dir, "target", profile, "toddy"])

    unless File.exists?(src) do
      Mix.raise("Build succeeded but binary not found at #{src}")
    end

    dest_dir = Path.join(["priv", "bin"])
    dest = Path.join(dest_dir, Toddy.Binary.download_name())

    File.mkdir_p!(dest_dir)
    File.cp!(src, dest)
    File.chmod!(dest, 0o755)

    Mix.shell().info("Installed to #{dest}")
  end

  # -- Extension registration -------------------------------------------------

  @doc """
  Returns the list of extension modules from application config.

  Users register extensions explicitly in their config.exs:

      config :toddy, extensions: [MyApp.SparklineExtension]

  This replaces the previous `:code.all_loaded/0` auto-discovery approach,
  which was unreliable because it only saw modules already loaded by the VM
  at the time of the call.
  """
  @spec configured_extensions() :: [module()]
  def configured_extensions do
    extensions = Application.get_env(:toddy, :extensions, [])

    unless is_list(extensions) do
      Mix.raise("""
      Invalid :extensions config for :toddy.

      Expected a list of modules, got: #{inspect(extensions)}

      Configure in config.exs:
          config :toddy, extensions: [MyApp.SparklineExtension]
      """)
    end

    # Validate that each module implements the Toddy.Extension behaviour.
    Enum.each(extensions, fn mod ->
      unless Code.ensure_loaded?(mod) do
        Mix.raise("Extension module #{inspect(mod)} could not be loaded")
      end

      behaviours = mod_behaviours(mod)

      unless Toddy.Extension in behaviours do
        Mix.raise(
          "Module #{inspect(mod)} is listed in :toddy :extensions config " <>
            "but does not implement the Toddy.Extension behaviour"
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

  # -- Extension build --------------------------------------------------------

  defp build_with_extensions(extensions, args) do
    build_dir = Path.join(Mix.Project.build_path(), "toddy")
    File.mkdir_p!(build_dir)

    bin_name = Toddy.Binary.build_name()
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

      {mod, Path.join(base, crate_rel)}
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
    source_path = Mix.ToddyHelpers.source_path()

    # Use local source paths if available, otherwise pull from crates.io
    {toddy_core_dep, toddy_bin_dep} =
      if source_path && File.dir?(source_path) do
        toddy_core_rel = Path.relative_to(Path.join(source_path, "toddy-core"), build_dir)
        toddy_bin_rel = Path.relative_to(Path.join(source_path, "toddy"), build_dir)

        {~s(toddy-core = { path = "#{toddy_core_rel}" }),
         ~s(toddy = { path = "#{toddy_bin_rel}" })}
      else
        {~s(toddy-core = "#{@binary_version}"), ~s(toddy = "#{@binary_version}")}
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
    #{toddy_core_dep}
    #{toddy_bin_dep}
    #{ext_deps}
    """
  end

  defp generate_main_rs(extensions) do
    ext_registrations =
      Enum.map_join(extensions, "\n        ", fn mod ->
        constructor = mod.rust_constructor()
        ".extension(#{constructor})"
      end)

    """
    // Auto-generated by mix toddy.build
    // Do not edit manually.

    use toddy_core::app::ToddyAppBuilder;

    fn main() -> iced::Result {
        let builder = ToddyAppBuilder::new()
                #{ext_registrations};
        toddy::run(builder)
    }
    """
  end
end
