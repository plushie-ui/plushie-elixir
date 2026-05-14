defmodule Mix.PlushiePackage do
  @moduledoc false

  @type renderer :: %{
          kind: :stock | :custom,
          source: String.t(),
          source_path: String.t(),
          payload_path: String.t()
        }

  @type platform :: %{
          icon: String.t()
        }

  @type manifest :: %{
          app_id: String.t(),
          app_name: String.t() | nil,
          app_version: String.t(),
          target: String.t(),
          host_sdk_version: String.t(),
          plushie_rust_version: String.t(),
          protocol_version: non_neg_integer(),
          renderer: renderer(),
          platform: platform(),
          host_command: [String.t()],
          payload_archive: String.t(),
          payload_hash: String.t(),
          payload_size: non_neg_integer()
        }

  @default_icon_payload_path "assets/plushie-checkbox-512x512.png"

  @spec default_icon_payload_path() :: String.t()
  def default_icon_payload_path, do: @default_icon_payload_path

  @spec package_target() :: String.t()
  def package_target do
    normalize_package_target(:os.type(), :erlang.system_info(:system_architecture))
  end

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

  @spec write_connect_wrapper!(
          path :: String.t(),
          release_name :: String.t(),
          app_module :: module()
        ) ::
          :ok
  def write_connect_wrapper!(path, release_name, app_module) do
    content = """
    #!/bin/sh
    set -eu
    DIR="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
    exec "$DIR/rel/#{release_name}/bin/#{release_name}" eval '#{connect_expression(app_module)}'
    """

    File.write!(path, content)
    File.chmod!(path, 0o755)
  end

  @spec materialize_default_icons!(payload_assets_dir :: String.t()) :: String.t()
  def materialize_default_icons!(payload_assets_dir) do
    materialize_default_icons!(payload_assets_dir, Mix.PlushieHelpers.resolve_cargo_plushie())
  end

  @doc false
  @spec materialize_default_icons!(
          payload_assets_dir :: String.t(),
          cargo_plushie :: {String.t(), [String.t()]}
        ) :: String.t()
  def materialize_default_icons!(payload_assets_dir, {cmd, prefix}) do
    File.mkdir_p!(payload_assets_dir)

    args = prefix ++ ["default-icons", "--out", payload_assets_dir]

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {_output, 0} ->
        icon_path = Path.join(payload_assets_dir, Path.basename(@default_icon_payload_path))

        unless File.exists?(icon_path) do
          Mix.raise("cargo plushie default-icons did not write #{icon_path}")
        end

        @default_icon_payload_path

      {output, status} ->
        Mix.shell().error(output)
        Mix.raise("cargo plushie default-icons failed with exit status #{status}")
    end
  end

  @spec copy_app_icon!(
          source_path :: String.t(),
          payload_assets_dir :: String.t()
        ) :: String.t()
  def copy_app_icon!(source_path, payload_assets_dir) do
    unless File.regular?(source_path) do
      Mix.raise("App icon was not found at #{source_path}")
    end

    File.mkdir_p!(payload_assets_dir)

    basename = Path.basename(source_path)
    payload_path = "assets/" <> basename
    File.cp!(source_path, Path.join(payload_assets_dir, basename))
    payload_path
  end

  @spec connect_expression(module()) :: String.t()
  def connect_expression(app_module) do
    "case Plushie.Connect.run(#{inspect(app_module)}, []) do :ok -> :ok; {:error, reason} -> raise RuntimeError, \"failed to connect Plushie app: \#{inspect(reason)}\" end"
  end

  @spec archive_payload!(payload_dir :: String.t(), archive_path :: String.t()) :: :ok
  def archive_payload!(payload_dir, archive_path) do
    validate_payload_archive_inputs!(payload_dir)
    File.mkdir_p!(Path.dirname(archive_path))

    tar = archive_tar!()

    tar_args = [
      "-C",
      payload_dir,
      "--sort=name",
      "--mtime=UTC 1970-01-01",
      "--owner=0",
      "--group=0",
      "--numeric-owner"
    ]

    cond do
      tar_supports_zstd?(tar) ->
        run!(tar, tar_args ++ ["--zstd", "-cf", archive_path, "."])

      System.find_executable("zstd") ->
        {tar_output, 0} = System.cmd(tar, tar_args ++ ["-cf", "-", "."], stderr_to_stdout: true)
        {_, 0} = System.cmd("zstd", ["-q", "-o", archive_path], input: tar_output)
        :ok

      true ->
        raise "missing required command: zstd"
    end
  end

  @spec payload_hash!(path :: String.t()) :: String.t()
  def payload_hash!(path) do
    :crypto.hash(:sha256, File.read!(path))
    |> Base.encode16(case: :lower)
  end

  @spec payload_size!(path :: String.t()) :: non_neg_integer()
  def payload_size!(path) do
    path |> File.stat!() |> Map.fetch!(:size)
  end

  @spec write_manifest!(path :: String.t(), manifest()) :: :ok
  def write_manifest!(path, manifest) do
    File.write!(path, manifest_toml(manifest))
  end

  @spec manifest_toml(manifest()) :: String.t()
  def manifest_toml(manifest) do
    """
    schema_version = 1
    app_id = #{toml_string(manifest.app_id)}
    #{app_name_toml(manifest.app_name)}app_version = #{toml_string(manifest.app_version)}
    target = #{toml_string(manifest.target)}
    host_sdk = "elixir"
    host_sdk_version = #{toml_string(manifest.host_sdk_version)}
    plushie_rust_version = #{toml_string(manifest.plushie_rust_version)}
    protocol_version = #{manifest.protocol_version}
    renderer_path = #{toml_string(manifest.renderer.payload_path)}
    host_command = #{toml_array(manifest.host_command)}
    working_dir = "."
    exec_env = []

    [platform]
    icon = #{toml_string(manifest.platform.icon)}

    [renderer]
    kind = #{toml_string(Atom.to_string(manifest.renderer.kind))}
    source = #{toml_string(manifest.renderer.source)}

    [payload]
    archive = #{toml_string(manifest.payload_archive)}
    hash = #{toml_string("sha256:" <> manifest.payload_hash)}
    size = #{manifest.payload_size}
    """
  end

  defp app_name_toml(nil), do: ""
  defp app_name_toml(app_name), do: "app_name = #{toml_string(app_name)}\n"

  defp validate_payload_archive_inputs!(payload_dir) do
    payload_dir
    |> File.ls!()
    |> Enum.each(fn _ -> :ok end)

    payload_dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(fn path ->
      case File.lstat!(path) do
        %File.Stat{type: :symlink} ->
          raise "payload contains unsupported symlink: #{Path.relative_to(path, payload_dir)}"

        %File.Stat{type: type} when type in [:device, :other] ->
          raise "payload contains unsupported special file: #{Path.relative_to(path, payload_dir)}"

        %File.Stat{type: :regular, links: links} when links > 1 ->
          raise "payload contains unsupported hard-linked file: #{Path.relative_to(path, payload_dir)}"

        _ ->
          :ok
      end
    end)
  end

  defp archive_tar! do
    cond do
      gnu_tar?("tar") -> "tar"
      System.find_executable("gtar") && gnu_tar?("gtar") -> "gtar"
      true -> raise "GNU tar or gtar is required for deterministic payload archives"
    end
  end

  defp gnu_tar?(command) do
    case System.cmd(command, ["--version"], stderr_to_stdout: true) do
      {output, 0} -> String.contains?(output, "GNU tar")
      _ -> false
    end
  rescue
    ErlangError -> false
  end

  defp tar_supports_zstd?(tar) do
    case System.cmd(tar, ["--help"], stderr_to_stdout: true) do
      {output, 0} -> String.contains?(output, "--zstd")
      _ -> false
    end
  end

  defp run!(command, args) do
    case System.cmd(command, args, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, status} ->
        raise "#{command} failed with exit status #{status}: #{output}"
    end
  end

  defp toml_string(value), do: Jason.encode!(value)
  defp toml_array(values), do: "[" <> Enum.map_join(values, ", ", &toml_string/1) <> "]"
end
