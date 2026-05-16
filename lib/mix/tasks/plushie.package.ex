defmodule Mix.Tasks.Plushie.Package do
  @shortdoc "Build a standalone Plushie package payload"
  @moduledoc """
  Builds a release payload and hands off to `bin/plushie package assemble`
  to complete the manifest, archive, hash, and optional handoff printing.

  The output is intended for `bin/plushie package portable`. All
  Elixir-specific release and renderer selection work stays in this task.
  The shared package launcher uses host-first startup: it runs the
  manifest's `[start].command`, and `Plushie.Connect.run/2` starts the
  payload-local renderer unless an explicit embedding flow provides
  `PLUSHIE_SOCKET`.

  Run with `MIX_ENV=prod` for production packaging.

  ## Usage

      MIX_ENV=prod mix plushie.package MyApp --app-id dev.example.my_app
      MIX_ENV=prod mix plushie.package MyApp --app-id dev.example.my_app --app-name "My App"
      MIX_ENV=prod mix plushie.package MyApp --app-id dev.example.my_app --renderer-kind custom
      mix plushie.package MyApp --write-package-config

  ## Options

  - `--app-id ID`: Package app identifier. Required.
  - `--app-name NAME`: Display app name.
  - `--release NAME`: Mix release name. Defaults to the current Mix app.
  - `--output DIR`: Output directory. Defaults to `dist`.
  - `--renderer-kind stock|custom`: Renderer selection. When absent, auto-detects based on
    native widget presence.
  - `--renderer-path PATH`: Use an existing renderer binary.
  - `--package-config PATH`: Forward to `bin/plushie package assemble --package-config`.
  - `--write-package-config`: Write a package config template and exit.
  - `--load MODULE`: Ensure a module is loaded before native widget discovery.
  """

  use Mix.Task

  @switches [
    app_id: :string,
    app_name: :string,
    release: :string,
    output: :string,
    renderer_kind: :string,
    renderer_path: :string,
    package_config: :string,
    write_package_config: :boolean,
    load: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, argv} = OptionParser.parse!(args, strict: @switches)

    Mix.PlushiePackage.package_target() |> Mix.PlushiePackage.validate_package_target!()

    app_module =
      case argv do
        [module_str] -> Module.concat([module_str])
        _ -> Mix.raise("Usage: mix plushie.package MyApp --app-id APP_ID")
      end

    release_name = opts[:release] || Atom.to_string(Mix.Project.config()[:app])
    package_config_path = opts[:package_config] || Mix.PlushiePackage.package_config_file()

    if opts[:write_package_config] do
      Mix.PlushiePackage.write_package_config!(
        package_config_path,
        Mix.PlushiePackage.default_start_config(release_name)
      )

      Mix.shell().info("Wrote #{package_config_path}")
    else
      app_id = opts[:app_id] || Mix.raise("--app-id is required")
      renderer_mode = parse_renderer_mode(opts[:renderer_kind])

      Mix.env() == :prod ||
        Mix.shell().info(
          "Packaging with MIX_ENV=#{Mix.env()}. Use MIX_ENV=prod for release builds."
        )

      Mix.Task.run("app.config")
      Mix.PlushieHelpers.compile_project!()
      Mix.PlushieHelpers.validate_module!(app_module)
      load_modules!(Keyword.get_values(opts, :load))
      Plushie.WidgetRegistry.invalidate()

      output_dir = opts[:output] || "dist"
      payload_dir = Path.join(output_dir, "payload")
      package_target = Mix.PlushiePackage.package_target()
      connect_wrapper = Mix.PlushiePackage.connect_wrapper_name(package_target)

      renderer = resolve_renderer!(renderer_mode, opts)

      Mix.shell().info("Building host release...")
      Mix.Task.rerun("release", [release_name, "--overwrite"])

      release_dir = Path.join([Mix.Project.build_path(), "rel", release_name])

      unless File.dir?(release_dir) do
        Mix.raise("Release was not found at #{release_dir}")
      end

      Mix.shell().info("Preparing payload...")
      File.rm_rf!(output_dir)
      File.mkdir_p!(Path.join(payload_dir, "bin"))
      File.mkdir_p!(Path.join(payload_dir, "rel"))
      File.cp_r!(release_dir, Path.join([payload_dir, "rel", release_name]))

      renderer_dest = Path.join(payload_dir, renderer.payload_path)
      File.mkdir_p!(Path.dirname(renderer_dest))
      File.cp!(renderer.source_path, renderer_dest)
      File.chmod!(renderer_dest, 0o755)

      Mix.PlushiePackage.write_connect_wrapper!(
        Path.join(payload_dir, connect_wrapper),
        release_name,
        app_module
      )

      manifest = %{
        app_id: app_id,
        app_name: opts[:app_name],
        app_version: Mix.Project.config()[:version],
        target: package_target,
        host_sdk_version: Plushie.version(),
        plushie_rust_version: plushie_rust_version(),
        protocol_version: Plushie.Protocol.protocol_version(),
        renderer: renderer,
        start_command: [connect_wrapper]
      }

      manifest_path = Path.join(output_dir, "plushie-package.toml")
      Mix.PlushiePackage.write_partial_manifest!(manifest_path, manifest)

      Mix.shell().info("Assembling package...")

      assemble_args =
        ["package", "assemble", "--manifest", manifest_path, "--payload-dir", payload_dir] ++
          if opts[:package_config], do: ["--package-config", opts[:package_config]], else: []

      Mix.PlushiePackage.run_plushie!(assemble_args)

      Mix.PlushieHelpers.warn_if_not_gitignored(output_dir)
    end
  end

  defp parse_renderer_mode(nil), do: :auto
  defp parse_renderer_mode("stock"), do: :stock
  defp parse_renderer_mode("custom"), do: :custom
  defp parse_renderer_mode(other), do: Mix.raise("Invalid --renderer-kind value: #{other}")

  defp load_modules!(module_strings) do
    Enum.each(module_strings, fn module_string ->
      module = Module.concat([module_string])
      Code.ensure_loaded!(module)
    end)
  end

  defp resolve_renderer!(mode, opts) do
    native = Plushie.WidgetRegistry.native_widgets()

    kind =
      case {mode, native} do
        {:auto, []} -> :stock
        {:auto, _} -> :custom
        {explicit, _} -> explicit
      end

    if kind == :stock and native != [] do
      Mix.raise("Native widget packaging requires a custom renderer. Use --renderer-kind custom.")
    end

    case kind do
      :stock -> resolve_stock_renderer!(opts)
      :custom -> resolve_custom_renderer!(opts, native)
    end
  end

  defp resolve_stock_renderer!(opts) do
    source_path =
      cond do
        bin = opts[:renderer_path] ->
          Mix.PlushiePackage.ensure_package_tools_available!()
          bin

        Mix.PlushieHelpers.source_path() ->
          renderer = build_stock_renderer_from_source!()
          Mix.PlushiePackage.ensure_package_tools_available!()
          renderer

        true ->
          Mix.Task.rerun("plushie.download", [])
          Plushie.Binary.path!()
      end

    validate_renderer!(source_path)

    %{
      kind: :stock,
      source_path: source_path,
      payload_path: Path.join("bin", renderer_executable_name("plushie-renderer"))
    }
  end

  defp resolve_custom_renderer!(opts, native) do
    native == [] &&
      Mix.shell().info("No native widgets were discovered, building a custom renderer anyway.")

    source_path =
      opts[:renderer_path] ||
        Path.join([Mix.Project.build_path(), "plushie-package", Plushie.Binary.build_name()])

    unless opts[:renderer_path] do
      Mix.Task.rerun("plushie.build", ["--release", "--bin-file", source_path])
    end

    Mix.PlushiePackage.ensure_package_tools_available!()
    validate_renderer!(source_path)

    %{
      kind: :custom,
      source_path: source_path,
      payload_path: Path.join("bin", Path.basename(source_path))
    }
  end

  defp build_stock_renderer_from_source! do
    source_path = Mix.PlushieHelpers.source_path!()
    manifest = Path.join(source_path, "Cargo.toml")

    unless File.exists?(manifest) do
      Mix.raise("PLUSHIE_RUST_SOURCE_PATH does not contain Cargo.toml: #{source_path}")
    end

    Mix.shell().info("Syncing stock renderer tools from #{source_path}...")
    version = plushie_rust_version()

    args = [
      "run",
      "--manifest-path",
      manifest,
      "-p",
      "cargo-plushie",
      "--bin",
      "plushie",
      "--release",
      "--quiet",
      "--",
      "tools",
      "sync",
      "--required-version",
      version
    ]

    case System.cmd("cargo", args, stderr_to_stdout: true) do
      {_output, 0} ->
        renderer = Path.join(Plushie.Binary.download_dir(), Plushie.Binary.download_name())

        unless File.regular?(renderer) do
          Mix.raise("tools sync exited 0 but renderer not found at #{renderer}")
        end

        renderer

      {output, status} ->
        Mix.shell().error(output)
        Mix.raise("cargo-plushie tools sync failed with exit status #{status}")
    end
  end

  defp validate_renderer!(path) do
    unless File.exists?(path) do
      Mix.raise("Renderer binary not found at #{path}")
    end

    File.chmod!(path, 0o755)
  end

  defp renderer_executable_name(name) do
    if :os.type() |> elem(0) == :win32, do: name <> ".exe", else: name
  end

  defp plushie_rust_version do
    System.get_env("PLUSHIE_RUST_VERSION") || Plushie.Binary.plushie_rust_version()
  end
end
