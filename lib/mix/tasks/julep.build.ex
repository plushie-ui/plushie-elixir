defmodule Mix.Tasks.Julep.Build do
  @moduledoc "Build the julep_gui renderer binary."
  @shortdoc "Build the julep_gui renderer"

  use Mix.Task

  @impl true
  def run(args) do
    # Ensure the project is compiled so we can discover extensions
    Mix.Task.run("compile", [])

    extensions = discover_extensions()

    if extensions == [] do
      build_stock(args)
    else
      check_collisions!(extensions)
      build_with_extensions(extensions, args)
    end
  end

  defp build_stock(args) do
    manifest_path = Path.join([File.cwd!(), "native", "julep_gui", "Cargo.toml"])

    unless File.exists?(manifest_path) do
      Mix.raise("Cargo.toml not found at #{manifest_path}")
    end

    release? = "--release" in args

    cmd_args = ["build", "--manifest-path", manifest_path]
    cmd_args = if release?, do: cmd_args ++ ["--release"], else: cmd_args
    cmd_args = cmd_args ++ feature_flags()

    Mix.shell().info("Building julep_gui#{if release?, do: " (release)", else: ""}...")

    case System.cmd("cargo", cmd_args, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info("Build succeeded.")
        if "--verbose" in args, do: Mix.shell().info(output)
        :ok

      {output, status} ->
        Mix.shell().error("Build failed (exit code #{status}):")
        Mix.shell().error(output)
        Mix.raise("cargo build failed")
    end
  end

  defp feature_flags do
    case Application.get_env(:julep, :iced_features, :all) do
      :all ->
        # Default Cargo features include builtin-all -- no extra flags needed.
        []

      features when is_list(features) ->
        # Build with only the requested widget features plus the non-widget defaults.
        widget_features = Enum.map(features, &Julep.Features.cargo_feature_name/1)
        all_features = widget_features ++ ["dialogs", "clipboard", "notifications"]
        ["--no-default-features", "--features", Enum.join(all_features, ",")]
    end
  end

  # -- Extension discovery ----------------------------------------------------

  @doc """
  Finds all loaded modules that implement the `Julep.Extension` behaviour.
  """
  @spec discover_extensions() :: [module()]
  def discover_extensions do
    for {mod, _} <- :code.all_loaded(),
        behaviours = mod_behaviours(mod),
        Julep.Extension in behaviours do
      mod
    end
  end

  defp mod_behaviours(mod) do
    if function_exported?(mod, :module_info, 1) do
      (mod.module_info(:attributes)[:behaviour] || []) ++
        (mod.module_info(:attributes)[:behavior] || [])
    end
  rescue
    _ -> []
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

  defp build_with_extensions(extensions, _args) do
    build_dir = Path.join(Mix.Project.build_path(), "julep_renderer")
    File.mkdir_p!(build_dir)

    crate_paths = resolve_crate_paths(extensions)
    generate_workspace(build_dir, extensions, crate_paths)

    ext_names = Enum.map_join(extensions, ", ", &inspect/1)

    Mix.shell().info(
      "Generated custom renderer workspace at #{build_dir} " <>
        "with #{length(extensions)} extension(s): #{ext_names}"
    )

    Mix.shell().info(
      "Note: cargo build is not yet supported for custom workspaces. " <>
        "The generated files are a preview of the future build output."
    )
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

  defp generate_workspace(build_dir, extensions, crate_paths) do
    cargo_toml = generate_cargo_toml(extensions, crate_paths, build_dir)
    File.write!(Path.join(build_dir, "Cargo.toml"), cargo_toml)

    src_dir = Path.join(build_dir, "src")
    File.mkdir_p!(src_dir)
    main_rs = generate_main_rs(extensions)
    File.write!(Path.join(src_dir, "main.rs"), main_rs)
  end

  defp generate_cargo_toml(extensions, crate_paths, build_dir) do
    julep_gui_path = Path.join([File.cwd!(), "native", "julep_gui"])
    julep_gui_rel = Path.relative_to(julep_gui_path, build_dir)

    ext_deps =
      Enum.map_join(extensions, "\n", fn mod ->
        path = crate_paths[mod]
        rel_path = Path.relative_to(path, build_dir)
        crate_name = Path.basename(path)
        "#{crate_name} = { path = \"#{rel_path}\" }"
      end)

    """
    [package]
    name = "julep-custom"
    version = "0.1.0"
    edition = "2021"

    [[bin]]
    name = "julep_gui"
    path = "src/main.rs"

    [dependencies]
    julep_gui = { path = "#{julep_gui_rel}" }
    #{ext_deps}
    """
  end

  defp generate_main_rs(extensions) do
    ext_registrations =
      Enum.map_join(extensions, "\n        ", fn mod ->
        constructor = mod.rust_constructor()
        ".extension(Box::new(#{constructor}))"
      end)

    """
    // Auto-generated by mix julep.build
    // Do not edit manually.

    fn main() {
        julep_gui::run(
            julep_gui::JulepAppBuilder::new()
                #{ext_registrations}
        );
    }
    """
  end
end
