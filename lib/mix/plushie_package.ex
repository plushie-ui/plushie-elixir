defmodule Mix.PlushiePackage do
  @moduledoc false

  @type renderer :: %{
          kind: :stock | :custom,
          source_path: String.t(),
          payload_path: String.t()
        }

  @type partial_manifest :: %{
          app_id: String.t(),
          app_name: String.t() | nil,
          app_version: String.t(),
          target: String.t(),
          host_sdk_version: String.t(),
          plushie_rust_version: String.t(),
          protocol_version: non_neg_integer(),
          renderer: renderer(),
          start_command: [String.t()]
        }

  @package_config_file "plushie-package.config.toml"

  @spec package_config_file() :: String.t()
  def package_config_file, do: @package_config_file

  @spec launcher_name() :: String.t()
  def launcher_name do
    if :os.type() |> elem(0) == :win32, do: "plushie-launcher.exe", else: "plushie-launcher"
  end

  @spec ensure_package_tools_available!() :: :ok
  def ensure_package_tools_available! do
    missing =
      [
        Path.join(Plushie.Binary.download_dir(), Plushie.Binary.tool_name()),
        Path.join(Plushie.Binary.download_dir(), launcher_name())
      ]
      |> Enum.reject(&File.regular?/1)

    if missing != [] do
      Mix.raise("""
      Portable packaging requires the managed Plushie tool set.
      Missing: #{Enum.join(missing, ", ")}
      Run `mix plushie.download`.
      """)
    end

    :ok
  end

  @spec portable_package_args(
          manifest_path :: String.t(),
          out_path :: String.t() | nil
        ) :: [String.t()]
  def portable_package_args(manifest_path, out_path \\ nil) do
    args = ["package", "portable", "--manifest", manifest_path]

    if out_path do
      args ++ ["--out", out_path]
    else
      args
    end
  end

  @spec run_portable_package!(
          manifest_path :: String.t(),
          out_path :: String.t() | nil,
          command :: String.t()
        ) :: :ok
  def run_portable_package!(
        manifest_path,
        out_path \\ nil,
        command \\ Path.join(Plushie.Binary.download_dir(), Plushie.Binary.tool_name())
      ) do
    args = portable_package_args(manifest_path, out_path)

    case System.cmd(command, args, stderr_to_stdout: true) do
      {output, 0} ->
        output != "" && Mix.shell().info(String.trim_trailing(output))
        :ok

      {output, status} ->
        output != "" && Mix.shell().error(String.trim_trailing(output))
        Mix.raise("#{command} #{Enum.join(args, " ")} failed with exit status #{status}")
    end
  end

  @spec run_plushie!(args :: [String.t()], command :: String.t()) :: :ok
  def run_plushie!(
        args,
        command \\ Path.join(Plushie.Binary.download_dir(), Plushie.Binary.tool_name())
      ) do
    case System.cmd(command, args, stderr_to_stdout: true) do
      {output, 0} ->
        output != "" && Mix.shell().info(String.trim_trailing(output))
        :ok

      {output, status} ->
        output != "" && Mix.shell().error(String.trim_trailing(output))
        Mix.raise("#{command} #{Enum.join(args, " ")} failed with exit status #{status}")
    end
  end

  @spec start_host_wrapper_name(target :: String.t()) :: String.t()
  def start_host_wrapper_name("windows-" <> _), do: "bin/start_host.cmd"
  def start_host_wrapper_name(_target), do: "bin/start_host"

  @spec default_start_config(release_name :: String.t()) :: map()
  @spec default_start_config(release_name :: String.t(), target :: String.t()) :: map()
  def default_start_config(_release_name, target \\ "posix") do
    %{
      working_dir: ".",
      start_command: [start_host_wrapper_name(target)],
      forward_env: default_forward_env()
    }
  end

  @spec write_package_config!(path :: String.t(), config :: map()) :: :ok
  def write_package_config!(path, config) do
    File.write!(path, package_config_toml(config))
  end

  @spec package_config_toml(config :: map()) :: String.t()
  def package_config_toml(config) do
    """
    # Plushie standalone package config.
    # Commit this file and edit it when the packaged app needs a
    # different entry point, working directory, or forwarded environment.

    config_version = 1

    [start]
    # Relative to the extracted app package.
    working_dir = #{toml_string(config.working_dir)}
    # Structured argv. The first item is the packaged host executable.
    # bin/start_host is the POSIX entry point.
    # On windows-* targets the SDK automatically uses bin/start_host.cmd.
    command = #{toml_array(config.start_command)}
    # Environment variable names copied from the parent process.
    forward_env = [
    #{Enum.map_join(config.forward_env, "\n", &("  " <> toml_string(&1) <> ","))}
    ]

    # [assets]
    # # Project-relative directory copied verbatim into the payload root
    # # during package assembly. When this section is absent, a directory
    # # named `package_assets/` next to this config file is used by
    # # convention if it exists.
    # dir = "package_assets"

    # [platform]
    # publisher = "Your Name"
    # copyright = "Copyright 2026 Your Name"
    # category = "productivity"
    # description = "Short app description"
    # bundle_id = "com.example.app"  # defaults to app_id on macOS

    # [platform.macos]
    # bundle_version = "1"  # CFBundleVersion build number

    # [platform.windows]
    # install_scope = "perUser"  # or "perMachine"
    """
  end

  @spec package_target() :: String.t()
  def package_target do
    normalize_package_target(:os.type(), :erlang.system_info(:system_architecture))
  end

  @spec validate_package_target!(target :: String.t()) :: String.t()
  def validate_package_target!(target), do: target

  @spec normalize_package_target({atom(), atom()}, charlist() | String.t()) :: String.t()
  def normalize_package_target(os_type, system_architecture) do
    os =
      case os_type do
        {:unix, :linux} -> "linux"
        {:unix, :darwin} -> "darwin"
        {:win32, _} -> "windows"
        other -> raise "unsupported package OS: #{inspect(other)}"
      end

    arch_string = system_architecture |> to_string() |> String.downcase()

    arch =
      cond do
        String.contains?(arch_string, "x86_64") or String.contains?(arch_string, "amd64") ->
          "x86_64"

        String.contains?(arch_string, "aarch64") or String.contains?(arch_string, "arm64") ->
          "aarch64"

        true ->
          raise "unsupported package architecture: #{arch_string}"
      end

    "#{os}-#{arch}"
  end

  @spec write_start_host_wrapper!(
          path :: String.t(),
          release_name :: String.t(),
          app_module :: module()
        ) ::
          :ok
  def write_start_host_wrapper!(path, release_name, app_module) do
    if String.ends_with?(path, ".cmd") do
      content = """
      @echo off
      set DIR=%~dp0..
      "%DIR%\\rel\\#{release_name}\\bin\\#{release_name}.bat" eval "#{connect_expression(app_module)}"
      """

      File.write!(path, content)
    else
      content = """
      #!/bin/sh
      set -eu
      DIR="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
      exec "$DIR/rel/#{release_name}/bin/#{release_name}" eval '#{connect_expression(app_module)}'
      """

      File.write!(path, content)
      File.chmod!(path, 0o755)
    end
  end

  @spec write_partial_manifest!(path :: String.t(), partial_manifest()) :: :ok
  def write_partial_manifest!(path, manifest) do
    File.write!(path, partial_manifest_toml(manifest))
  end

  @spec partial_manifest_toml(partial_manifest()) :: String.t()
  def partial_manifest_toml(manifest) do
    """
    schema_version = 1
    app_id = #{toml_string(manifest.app_id)}
    #{app_name_toml(manifest.app_name)}app_version = #{toml_string(manifest.app_version)}
    target = #{toml_string(manifest.target)}
    host_sdk = "elixir"
    host_sdk_version = #{toml_string(manifest.host_sdk_version)}
    plushie_rust_version = #{toml_string(manifest.plushie_rust_version)}
    protocol_version = #{manifest.protocol_version}

    [start]
    command = #{toml_array(manifest.start_command)}

    [renderer]
    path = #{toml_string(manifest.renderer.payload_path)}
    kind = #{toml_string(Atom.to_string(manifest.renderer.kind))}
    """
  end

  @spec connect_expression(module()) :: String.t()
  def connect_expression(app_module) do
    "case Plushie.Connect.run(#{inspect(app_module)}, []) do :ok -> :ok; {:error, reason} -> raise RuntimeError, \"failed to connect Plushie app: \#{inspect(reason)}\" end"
  end

  defp app_name_toml(nil), do: ""
  defp app_name_toml(app_name), do: "app_name = #{toml_string(app_name)}\n"

  defp default_forward_env do
    [
      "PATH",
      "HOME",
      "LANG",
      "LC_ALL",
      "XDG_RUNTIME_DIR",
      "WAYLAND_DISPLAY",
      "DISPLAY"
    ]
  end

  defp toml_string(value), do: Jason.encode!(value)
  defp toml_array(values), do: "[" <> Enum.map_join(values, ", ", &toml_string/1) <> "]"
end
