defmodule Mix.Tasks.Plushie.Build do
  @min_rust_version {1, 92, 0}

  @moduledoc """
  Build the plushie binary and/or WASM renderer from source.

  Generates a Cargo workspace and builds it. When a local source checkout
  is available (`PLUSHIE_SOURCE_PATH`), dependencies use local paths for
  development. Otherwise, dependencies are pulled from crates.io using
  the `:binary_version` from mix.exs.

  When native widgets are detected, the workspace includes each widget's
  Rust crate and the generated `main.rs` registers them at startup.

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
  - `--update` -- Force dependency re-resolution (deletes the tracked lock file)

  ## Config

  Artifact selection and output paths can be set in `config.exs`:

      config :plushie,
        artifacts: [:bin, :wasm],       # which artifacts to build
        bin_file: "priv/bin/plushie-renderer",  # binary destination
        wasm_dir: "priv/static"         # WASM output directory

  CLI flags override config. Default artifacts: `[:bin]`.

  ## Native widgets

  Native widgets are auto-detected via the `Plushie.Widget` protocol.
  Any module that implements the protocol and exports `native_crate/0`
  is included in the build. No explicit configuration is needed.

  The task validates that no two widgets claim the same type name.
  A Cargo workspace is generated under the Mix build directory with a
  `main.rs` that registers each native widget.
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
          update: :boolean,
          bin_file: :string,
          wasm_dir: :string
        ]
      )

    Mix.PlushieHelpers.warn_if_unconfigured()
    {want_bin?, want_wasm?} = Mix.PlushieHelpers.resolve_artifacts(opts)
    release? = opts[:release] || false
    verbose? = opts[:verbose] || false
    update? = opts[:update] || false

    if want_bin?, do: build_bin(release?, verbose?, update?, opts)
    if want_wasm?, do: build_wasm(release?, verbose?, opts)
  end

  defp build_bin(release?, verbose?, update?, opts) do
    check_rust_toolchain()
    check_cargo()

    # Ensure the project is compiled so widget modules are available
    # for protocol-based discovery.
    Mix.Task.run("compile", [])

    native = Plushie.WidgetRegistry.native_widgets()

    if native != [] do
      check_collisions!(native)
      check_crate_name_collisions!(native)
    end

    build_workspace(native, release?, verbose?, update?, opts)
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

    release? = release? or Application.get_env(:plushie, :build_profile) == :release
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

  # -- Collision detection ----------------------------------------------------

  @doc """
  Raises `Mix.Error` if any two native widgets claim the same type name.
  """
  @spec check_collisions!(widgets :: [module()]) :: :ok
  def check_collisions!(widgets) do
    all_types =
      Enum.flat_map(widgets, fn mod ->
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
      Widget type name collision detected:
      #{Enum.join(messages, "\n")}

      Each type name must be handled by exactly one widget.\
      """)
    end

    :ok
  end

  @doc """
  Raises `Mix.Error` if any two native widgets produce the same Cargo crate name.

  The crate name is `Path.basename/1` of each widget's `native_crate/0`
  path. Two widgets at `native/widget/` and `other/widget/` would both
  produce `widget`, causing a Cargo dependency conflict.
  """
  @spec check_crate_name_collisions!(widgets :: [module()]) :: :ok
  def check_crate_name_collisions!(widgets) do
    all_crates =
      Enum.map(widgets, fn mod ->
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
      Widget crate name collision detected:
      #{Enum.join(messages, "\n")}

      Each widget's native_crate path must have a unique basename.
      Rename one of the crate directories to resolve the conflict.\
      """)
    end

    :ok
  end

  # -- Workspace build --------------------------------------------------------

  @lock_file "native/plushie/Cargo.lock"

  defp build_workspace(native_widgets, release?, verbose?, update?, opts) do
    build_dir = Path.join(Mix.Project.build_path(), "plushie-renderer")
    File.mkdir_p!(build_dir)

    bin_name =
      if native_widgets == [],
        do: "plushie-renderer",
        else: Plushie.Binary.build_name()

    crate_paths = resolve_crate_paths(native_widgets)

    if crate_paths != %{} do
      check_widget_versions!(crate_paths)
    end

    generate_workspace(build_dir, bin_name, native_widgets, crate_paths)

    workspace_lock = Path.join(build_dir, "Cargo.lock")

    if update? do
      File.rm(workspace_lock)
    else
      check_lock_version!()
      copy_lock_to_workspace(build_dir)
    end

    source_info =
      if Mix.PlushieHelpers.source_path(),
        do: "local source",
        else: "crates.io v#{Plushie.Binary.binary_version()}"

    if native_widgets != [] do
      ext_names = Enum.map_join(native_widgets, ", ", &inspect/1)
      Mix.shell().info("Native widgets: #{ext_names}")
    end

    Mix.shell().info("Source: #{source_info}")

    release? = release? or Application.get_env(:plushie, :build_profile) == :release
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
        copy_lock_from_workspace(build_dir)
        ext = if :os.type() |> elem(0) == :win32, do: ".exe", else: ""
        binary = Path.join([build_dir, "target", profile, bin_name <> ext])
        install_bin_to(binary, opts)

      {output, status} ->
        Mix.shell().error("Build failed (exit code #{status}):")
        Mix.shell().error(output)
        Mix.raise("cargo build failed")
    end
  end

  # -- Cargo.lock management --------------------------------------------------

  defp copy_lock_to_workspace(build_dir) do
    if File.exists?(@lock_file) do
      File.cp!(@lock_file, Path.join(build_dir, "Cargo.lock"))
    end
  end

  defp copy_lock_from_workspace(build_dir) do
    workspace_lock = Path.join(build_dir, "Cargo.lock")

    if File.exists?(workspace_lock) do
      File.mkdir_p!(Path.dirname(@lock_file))
      File.cp!(workspace_lock, @lock_file)
    end
  end

  defp check_lock_version! do
    if File.exists?(@lock_file) do
      content = File.read!(@lock_file)
      expected = Plushie.Binary.binary_version()

      case Regex.run(
             ~r/name = "plushie-ext"\nversion = "(\d+\.\d+\.\d+)"/,
             content
           ) do
        [_, locked_version] when locked_version != expected ->
          Mix.raise("""
          Cargo.lock version mismatch: plushie-ext #{locked_version} is locked \
          but BINARY_VERSION is #{expected}.

          Run `mix plushie.build --update` to re-resolve dependencies.\
          """)

        _ ->
          :ok
      end
    end
  end

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

      unless String.starts_with?(resolved, allowed_root) do
        Mix.raise(
          "Widget #{inspect(mod)} native_crate path #{inspect(crate_rel)} " <>
            "resolves to #{resolved}, which is outside the allowed directory #{allowed_root}"
        )
      end

      {mod, resolved}
    end)
  end

  defp generate_workspace(build_dir, bin_name, widgets, crate_paths) do
    cargo_toml = generate_cargo_toml(bin_name, widgets, crate_paths, build_dir)
    write_if_changed(Path.join(build_dir, "Cargo.toml"), cargo_toml)

    src_dir = Path.join(build_dir, "src")
    File.mkdir_p!(src_dir)
    main_rs = generate_main_rs(widgets)
    write_if_changed(Path.join(src_dir, "main.rs"), main_rs)
  end

  # Writes content to path only if it differs from the existing file.
  # Avoids mtime changes on identical content so Cargo skips recompilation.
  defp write_if_changed(path, content) do
    if File.read(path) == {:ok, content} do
      :ok
    else
      File.write!(path, content)
    end
  end

  # Each native widget crate should depend on a plushie-ext version compatible
  # with Plushie.Binary.binary_version(). Check before building to give a clear
  # error instead of a cryptic Cargo resolution failure.

  defp check_widget_versions!(crate_paths) do
    expected = Version.parse!(Plushie.Binary.binary_version())

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
            "Widget #{inspect(mod)}: no plushie-ext dependency found in #{cargo_toml_path}"
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
            "Widget #{inspect(mod)} depends on plushie-ext #{dep_version_str}, " <>
              "but this project targets #{expected}. " <>
              "Update the widget's Rust crate to a compatible version."
          )
        end

      :error ->
        :ok
    end
  end

  # Pre-1.0 (0.x): major AND minor must match. 1.0+: major must match.
  # Pre-1.0, the 1.0+ branch is unreachable. Dialyzer flags this.
  # The branch is needed for when we ship 1.0.
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

  defp generate_cargo_toml(bin_name, widgets, crate_paths, build_dir) do
    source_path = Mix.PlushieHelpers.source_path()

    # Use local source paths if available, otherwise pull from crates.io.
    # The plushie-renderer workspace has two crates native widgets need:
    #   plushie-ext       -- core library (widget types, protocols, widget API)
    #   plushie-renderer  -- binary entry point (run function)
    {plushie_ext_dep, plushie_renderer_dep} =
      if source_path && File.dir?(source_path) do
        ext_rel = Path.relative_to(Path.join(source_path, "plushie-ext"), build_dir)
        renderer_rel = Path.relative_to(Path.join(source_path, "plushie-renderer"), build_dir)

        {~s(plushie-ext = { path = "#{ext_rel}" }),
         ~s(plushie-renderer = { path = "#{renderer_rel}" })}
      else
        {~s(plushie-ext = "#{Plushie.Binary.binary_version()}"),
         ~s(plushie-renderer = "#{Plushie.Binary.binary_version()}")}
      end

    ext_deps =
      if widgets == [] do
        ""
      else
        "\n" <>
          Enum.map_join(widgets, "\n", fn mod ->
            path = crate_paths[mod]
            rel_path = Path.relative_to(path, build_dir)
            crate_name = Path.basename(path)
            "#{crate_name} = { path = \"#{rel_path}\" }"
          end)
      end

    # When using local source paths, add [patch.crates-io] so widget
    # crates that depend on plushie-ext from crates.io get redirected to
    # the same local checkout. Without this, Cargo treats the path dep and
    # the crates.io dep as different crates and trait impls don't match.
    #
    # Also patch plushie-iced-* subcrates when the vendored iced fork is
    # a sibling of the source path (../plushie-iced). The renderer's own
    # workspace does the same thing; without these patches, iced types
    # from crates.io and the local fork are treated as distinct types.
    patch_section =
      if source_path && File.dir?(source_path) do
        ext_path = Path.join(source_path, "plushie-ext")
        renderer_path = Path.join(source_path, "plushie-renderer")

        iced_patches = iced_patch_entries(source_path)

        """

        [patch.crates-io]
        plushie-ext = { path = "#{ext_path}" }
        plushie-renderer = { path = "#{renderer_path}" }
        #{iced_patches}\
        """
      else
        ""
      end

    # Use underscores for the Cargo package name (Cargo convention)
    package_name = String.replace(bin_name, "-", "_")

    deps =
      [plushie_ext_dep, plushie_renderer_dep]
      |> Enum.join("\n")

    sections =
      [
        """
        [package]
        name = "#{package_name}"
        version = "#{Mix.Project.config()[:version]}"
        edition = "2024"

        [[bin]]
        name = "#{bin_name}"
        path = "src/main.rs"

        [dependencies]
        #{deps}\
        """,
        ext_deps,
        patch_section
      ]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")

    String.trim_trailing(sections) <> "\n"
  end

  # Discovers plushie-iced subcrates from the vendored iced fork (expected
  # as a sibling directory of the source path) and returns patch lines.
  defp iced_patch_entries(source_path) do
    iced_root = source_path |> Path.dirname() |> Path.join("plushie-iced")

    if File.dir?(iced_root) do
      # The root crate (plushie-iced itself)
      root_entry = "plushie-iced = { path = \"#{iced_root}\" }"

      # Subcrates: each subdirectory with a Cargo.toml containing a
      # plushie-iced-* package name
      sub_entries =
        iced_root
        |> File.ls!()
        |> Enum.sort()
        |> Enum.flat_map(&iced_subcrate_entry(iced_root, &1))

      Enum.join([root_entry | sub_entries], "\n")
    else
      ""
    end
  end

  defp iced_subcrate_entry(iced_root, dir) do
    cargo_path = Path.join([iced_root, dir, "Cargo.toml"])

    with true <- File.regular?(cargo_path),
         "plushie-iced-" <> _ = name <- extract_cargo_package_name(cargo_path) do
      ["#{name} = { path = \"#{Path.join(iced_root, dir)}\" }"]
    else
      _ -> []
    end
  end

  defp extract_cargo_package_name(cargo_path) do
    case File.read(cargo_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.find_value(fn line ->
          case Regex.run(~r/^name\s*=\s*"([^"]+)"/, String.trim(line)) do
            [_, name] -> name
            _ -> nil
          end
        end)

      {:error, _} ->
        nil
    end
  end

  # Validates Rust constructor expressions. Matches:
  #   gauge::GaugeWidget::new()      -- module path with call
  #   MyExt::<Config>::new()            -- turbofish generics
  #   MyExt::new                        -- path without parens
  #   create_widget()                   -- bare function call
  @rust_constructor_pattern ~r/^[A-Za-z_][A-Za-z0-9_:<>, ]*(\([^)]*\))?$/

  defp validate_rust_constructor!(mod, constructor) do
    unless Regex.match?(@rust_constructor_pattern, constructor) do
      Mix.raise(
        "Widget #{inspect(mod)} rust_constructor #{inspect(constructor)} " <>
          "contains invalid characters. Expected a Rust identifier, path (::), " <>
          "or simple invocation (e.g. \"MyExt::new()\")"
      )
    end
  end

  defp generate_main_rs(widgets) do
    builder_expr =
      if widgets == [] do
        "PlushieAppBuilder::new()"
      else
        registrations =
          Enum.map_join(widgets, "\n        ", fn mod ->
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
