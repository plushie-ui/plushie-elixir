defmodule Mix.Tasks.Plushie.Package do
  @shortdoc "Build a standalone Plushie package payload"
  @moduledoc """
  Builds a release payload archive and `plushie-package.toml` manifest
  for a Plushie Elixir app.

  The output is intended for `cargo plushie package`, while all
  Elixir-specific release and renderer selection work stays in the SDK.

  ## Usage

      MIX_ENV=prod mix plushie.package MyApp --app-id dev.example.my_app
      MIX_ENV=prod mix plushie.package MyApp --app-id dev.example.my_app --app-name "My App"
      MIX_ENV=prod mix plushie.package MyApp --app-id dev.example.my_app --renderer custom
      MIX_ENV=prod mix plushie.package MyApp --app-id dev.example.my_app --icon priv/app-icon.png

  ## Options

  - `--app-id ID`: Package app identifier. Required.
  - `--app-name NAME`: Display app name.
  - `--release NAME`: Mix release name. Defaults to the current Mix app.
  - `--output DIR`: Output directory. Defaults to `dist`.
  - `--renderer stock|custom|auto`: Renderer selection. Defaults to `auto`.
  - `--renderer-bin PATH`: Use an existing renderer binary.
  - `--icon PATH`: Use an app icon instead of the default Plushie icon.
  - `--load MODULE`: Ensure a module is loaded before native widget discovery.
  """

  use Mix.Task

  @switches [
    app_id: :string,
    app_name: :string,
    release: :string,
    output: :string,
    renderer: :string,
    renderer_bin: :string,
    icon: :string,
    load: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, argv} = OptionParser.parse!(args, strict: @switches)

    app_module =
      case argv do
        [module_str] -> Module.concat([module_str])
        _ -> Mix.raise("Usage: mix plushie.package MyApp --app-id APP_ID")
      end

    app_id = opts[:app_id] || Mix.raise("--app-id is required")
    renderer_mode = parse_renderer_mode(opts[:renderer] || "auto")

    Mix.env() == :prod ||
      Mix.shell().info(
        "Packaging with MIX_ENV=#{Mix.env()}. Use MIX_ENV=prod for release builds."
      )

    Mix.Task.run("app.config")
    Mix.PlushieHelpers.compile_project!()
    Mix.PlushieHelpers.validate_module!(app_module)
    load_modules!(Keyword.get_values(opts, :load))
    Plushie.WidgetRegistry.invalidate()

    release_name = opts[:release] || Atom.to_string(Mix.Project.config()[:app])
    output_dir = opts[:output] || "dist"
    payload_dir = Path.join(output_dir, "payload")

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
      Path.join(payload_dir, "bin/connect"),
      release_name,
      app_module
    )

    platform_icon = prepare_package_icon!(opts, payload_dir)

    Mix.shell().info("Writing archive...")
    archive_path = Path.join(output_dir, "payload.tar.zst")
    Mix.PlushiePackage.archive_payload!(payload_dir, archive_path)

    manifest = %{
      app_id: app_id,
      app_name: opts[:app_name],
      app_version: Mix.Project.config()[:version],
      target: Mix.PlushiePackage.package_target(),
      host_sdk_version: Plushie.version(),
      plushie_rust_version: plushie_rust_version(),
      protocol_version: Plushie.Protocol.protocol_version(),
      renderer: renderer,
      platform: %{icon: platform_icon},
      start_command: ["bin/connect"],
      working_dir: ".",
      forward_env: Mix.PlushiePackage.default_forward_env(),
      payload_archive: "payload.tar.zst",
      payload_hash: Mix.PlushiePackage.payload_hash!(archive_path),
      payload_size: Mix.PlushiePackage.payload_size!(archive_path)
    }

    Mix.PlushiePackage.write_manifest!(Path.join(output_dir, "plushie-package.toml"), manifest)

    Mix.shell().info("Wrote #{archive_path}")
    Mix.shell().info("Wrote #{Path.join(output_dir, "plushie-package.toml")}")
    Mix.shell().info("Build launcher with:")

    Mix.shell().info(
      "  cargo plushie package --manifest #{Path.join(output_dir, "plushie-package.toml")} --release"
    )
  end

  defp parse_renderer_mode("auto"), do: :auto
  defp parse_renderer_mode("stock"), do: :stock
  defp parse_renderer_mode("custom"), do: :custom
  defp parse_renderer_mode(other), do: Mix.raise("Invalid --renderer value: #{other}")

  defp load_modules!(module_strings) do
    Enum.each(module_strings, fn module_string ->
      module = Module.concat([module_string])
      Code.ensure_loaded!(module)
    end)
  end

  defp prepare_package_icon!(opts, payload_dir) do
    payload_assets_dir = Path.join(payload_dir, "assets")

    case opts[:icon] do
      nil ->
        Mix.PlushiePackage.materialize_default_icons!(payload_assets_dir)

      icon_path ->
        Mix.PlushiePackage.copy_app_icon!(icon_path, payload_assets_dir)
    end
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
      Mix.raise("Native widget packaging requires a custom renderer. Use --renderer custom.")
    end

    case kind do
      :stock -> resolve_stock_renderer!(opts)
      :custom -> resolve_custom_renderer!(opts, native)
    end
  end

  defp resolve_stock_renderer!(opts) do
    source_path =
      cond do
        opts[:renderer_bin] ->
          opts[:renderer_bin]

        Mix.PlushieHelpers.source_path() ->
          build_stock_renderer_from_source!()

        true ->
          Plushie.Binary.path!()
      end

    validate_renderer!(source_path)

    %{
      kind: :stock,
      source: if(opts[:renderer_bin], do: "local-path", else: "local-resolve"),
      source_path: source_path,
      payload_path: Path.join("bin", renderer_executable_name("plushie-renderer"))
    }
  end

  defp resolve_custom_renderer!(opts, native) do
    native == [] &&
      Mix.shell().info("No native widgets were discovered, building a custom renderer anyway.")

    source_path =
      opts[:renderer_bin] ||
        Path.join([Mix.Project.build_path(), "plushie-package", Plushie.Binary.build_name()])

    unless opts[:renderer_bin] do
      Mix.Task.rerun("plushie.build", ["--release", "--bin-file", source_path])
    end

    validate_renderer!(source_path)

    %{
      kind: :custom,
      source: if(opts[:renderer_bin], do: "local-path", else: "local-build"),
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

    Mix.shell().info("Building stock plushie renderer from #{source_path}...")

    case System.cmd("cargo", ["build", "--release", "-p", "plushie-renderer"],
           cd: source_path,
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        Path.join([
          source_path,
          "target",
          "release",
          renderer_executable_name("plushie-renderer")
        ])

      {output, status} ->
        Mix.shell().error(output)
        Mix.raise("cargo build failed with exit status #{status}")
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
