defmodule Mix.PlushiePackage do
  @moduledoc false

  @type renderer :: %{
          kind: :stock | :custom,
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
          start_command: [String.t()],
          working_dir: String.t(),
          forward_env: [String.t()],
          payload_archive: String.t(),
          payload_hash: String.t(),
          payload_size: non_neg_integer()
        }

  @default_icon_payload_path "assets/plushie-checkbox-512x512.png"
  @package_config_file "plushie-package.config.toml"
  @default_forward_env [
    "PATH",
    "HOME",
    "LANG",
    "LC_ALL",
    "XDG_RUNTIME_DIR",
    "WAYLAND_DISPLAY",
    "DISPLAY"
  ]

  @spec default_icon_payload_path() :: String.t()
  def default_icon_payload_path, do: @default_icon_payload_path

  @spec default_forward_env() :: [String.t()]
  def default_forward_env, do: @default_forward_env

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
          out_path :: String.t() | nil,
          strict_tools :: boolean()
        ) :: [String.t()]
  def portable_package_args(manifest_path, out_path \\ nil, strict_tools \\ false) do
    args = ["package", "portable", "--manifest", manifest_path]

    args =
      if strict_tools do
        args ++ ["--strict-tools"]
      else
        args
      end

    if out_path do
      args ++ ["--out", out_path]
    else
      args
    end
  end

  @spec run_portable_package!(
          manifest_path :: String.t(),
          out_path :: String.t() | nil,
          strict_tools :: boolean(),
          command :: String.t()
        ) :: :ok
  def run_portable_package!(
        manifest_path,
        out_path \\ nil,
        strict_tools \\ false,
        command \\ Path.join(Plushie.Binary.download_dir(), Plushie.Binary.tool_name())
      ) do
    args = portable_package_args(manifest_path, out_path, strict_tools)

    case System.cmd(command, args, stderr_to_stdout: true) do
      {output, 0} ->
        output != "" && Mix.shell().info(String.trim_trailing(output))
        :ok

      {output, status} ->
        output != "" && Mix.shell().error(String.trim_trailing(output))
        Mix.raise("#{command} #{Enum.join(args, " ")} failed with exit status #{status}")
    end
  end

  @spec default_start_config(release_name :: String.t()) :: map()
  def default_start_config(_release_name) do
    %{
      working_dir: ".",
      start_command: ["bin/connect"],
      forward_env: default_forward_env()
    }
  end

  @spec read_package_config!(path :: String.t()) :: map()
  def read_package_config!(path) do
    unless File.regular?(path) do
      Mix.raise("Package config was not found at #{path}")
    end

    path
    |> File.read!()
    |> parse_package_config!()
  end

  @spec read_default_package_config!(path :: String.t()) :: map() | nil
  def read_default_package_config!(path) do
    if File.regular?(path), do: read_package_config!(path), else: nil
  end

  @spec write_package_config!(path :: String.t(), config :: map()) :: :ok
  def write_package_config!(path, config) do
    validate_start_config!(config)
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
    command = #{toml_array(config.start_command)}
    # Environment variable names copied from the parent process.
    forward_env = [
    #{Enum.map_join(config.forward_env, "\n", &("  " <> toml_string(&1) <> ","))}
    ]
    """
  end

  @spec package_target() :: String.t()
  def package_target do
    normalize_package_target(:os.type(), :erlang.system_info(:system_architecture))
  end

  @spec validate_package_target!(target :: String.t()) :: String.t()
  def validate_package_target!("windows-" <> _ = target) do
    Mix.raise("""
    Windows standalone packaging is not supported by the Elixir SDK yet.
    The current package flow writes a Unix bin/connect wrapper. Add a
    Windows-specific host command before producing #{target} packages.
    """)
  end

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
        tmp_tar = archive_path <> ".tar"

        try do
          run!(tar, tar_args ++ ["-cf", tmp_tar, "."])
          run!("zstd", ["-q", "-f", "-o", archive_path, tmp_tar])
        after
          File.rm(tmp_tar)
        end

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

    [start]
    working_dir = #{toml_string(manifest.working_dir)}
    command = #{toml_array(manifest.start_command)}
    forward_env = #{toml_array(manifest.forward_env)}

    [platform]
    icon = #{toml_string(manifest.platform.icon)}

    [renderer]
    path = #{toml_string(manifest.renderer.payload_path)}
    kind = #{toml_string(Atom.to_string(manifest.renderer.kind))}

    [payload]
    archive = #{toml_string(manifest.payload_archive)}
    hash = #{toml_string("sha256:" <> manifest.payload_hash)}
    size = #{manifest.payload_size}
    """
  end

  defp app_name_toml(nil), do: ""
  defp app_name_toml(app_name), do: "app_name = #{toml_string(app_name)}\n"

  defp parse_package_config!(text) do
    config_version =
      case Regex.run(~r/^\s*config_version\s*=\s*(\d+)\s*$/m, text) do
        [_, "1"] -> 1
        [_, version] -> Mix.raise("Unsupported package config config_version #{version}")
        nil -> Mix.raise("Package config must include config_version = 1")
      end

    start = section!(text, "start")

    config = %{
      config_version: config_version,
      working_dir: string_field!(start, "working_dir"),
      start_command: array_field!(start, "command"),
      forward_env: array_field!(start, "forward_env")
    }

    validate_start_config!(config)
    Map.drop(config, [:config_version])
  end

  defp section!(text, name) do
    case Regex.run(~r/^\s*\[#{Regex.escape(name)}\]\s*$(.*?)(?=^\s*\[|\z)/ms, text) do
      [_, body] -> body
      nil -> Mix.raise("Package config must include [#{name}]")
    end
  end

  defp string_field!(section, name) do
    section
    |> field!(name)
    |> Jason.decode!()
    |> case do
      value when is_binary(value) -> value
      _ -> Mix.raise("Package config #{name} must be a string")
    end
  rescue
    Jason.DecodeError -> Mix.raise("Package config #{name} must be a TOML basic string")
  end

  defp array_field!(section, name) do
    value = field!(section, name)

    unless String.starts_with?(value, "[") and String.ends_with?(value, "]") do
      Mix.raise("Package config #{name} must be an array of strings")
    end

    value
    |> String.trim()
    |> String.trim_leading("[")
    |> String.trim_trailing("]")
    |> parse_string_array_items!(name, [], true)
  rescue
    Jason.DecodeError -> Mix.raise("Package config #{name} must be an array of strings")
  end

  defp parse_string_array_items!(text, name, values, expecting_value) do
    text = String.trim_leading(text)

    cond do
      text == "" ->
        Enum.reverse(values)

      String.starts_with?(text, ",") ->
        if expecting_value do
          Mix.raise("Package config #{name} must be an array of strings")
        end

        text
        |> String.trim_leading(",")
        |> parse_string_array_items!(name, values, true)

      expecting_value and String.starts_with?(text, "\"") ->
        {literal, rest} = take_toml_basic_string!(text, name)
        value = Jason.decode!(literal)
        parse_string_array_items!(rest, name, [value | values], false)

      true ->
        Mix.raise("Package config #{name} must be an array of strings")
    end
  end

  defp take_toml_basic_string!(text, name) do
    case Regex.run(~r/^"(?:\\.|[^"\\])*"/, text) do
      [literal] -> {literal, String.replace_prefix(text, literal, "")}
      nil -> Mix.raise("Package config #{name} must be an array of strings")
    end
  end

  defp field!(section, name) do
    lines = section |> String.split("\n") |> Enum.map(&String.trim/1)
    prefix = name <> " ="

    case collect_field(lines, prefix, []) do
      nil -> Mix.raise("Package config [start] must include #{name}")
      value -> value
    end
  end

  defp collect_field([], _prefix, _seen), do: nil

  defp collect_field([line | rest], prefix, _seen) do
    cond do
      line == "" or comment?(line) ->
        collect_field(rest, prefix, [])

      String.starts_with?(line, prefix) ->
        value = line |> String.replace_prefix(prefix, "") |> String.trim()

        if String.starts_with?(value, "[") and not String.contains?(value, "]") do
          collect_array_field(rest, [value])
        else
          value
        end

      true ->
        collect_field(rest, prefix, [])
    end
  end

  defp collect_array_field([], _parts), do: Mix.raise("Package config array is unterminated")

  defp collect_array_field([line | rest], parts) do
    trimmed = line |> strip_comment() |> String.trim()
    parts = [trimmed | parts]

    if String.contains?(trimmed, "]") do
      parts |> Enum.reverse() |> Enum.join("\n")
    else
      collect_array_field(rest, parts)
    end
  end

  defp strip_comment(line) do
    strip_comment_chars(String.graphemes(line), false, [])
  end

  defp strip_comment_chars([], _in_string, acc), do: acc |> Enum.reverse() |> Enum.join()

  defp strip_comment_chars(["\\" | [next | rest]], true, acc) do
    strip_comment_chars(rest, true, [next, "\\" | acc])
  end

  defp strip_comment_chars(["\"" | rest], in_string, acc) do
    strip_comment_chars(rest, not in_string, ["\"" | acc])
  end

  defp strip_comment_chars(["#" | _rest], false, acc) do
    acc |> Enum.reverse() |> Enum.join()
  end

  defp strip_comment_chars([char | rest], in_string, acc) do
    strip_comment_chars(rest, in_string, [char | acc])
  end

  defp comment?(line), do: line |> String.trim() |> String.starts_with?("#")

  defp validate_start_config!(config) do
    validate_payload_path!("start.working_dir", config.working_dir)

    case config.start_command do
      [program | _] when is_binary(program) and program != "" ->
        validate_payload_path!("start.command[0]", program)

      _ ->
        Mix.raise("Package config start.command must contain a non-empty argv")
    end

    if Enum.any?(config.start_command, &(&1 == "")) do
      Mix.raise("Package config start.command must contain a non-empty argv")
    end

    Enum.each(config.forward_env, fn name ->
      cond do
        String.trim(name) == "" or String.contains?(name, [",", "="]) ->
          Mix.raise("Package config start.forward_env contains invalid environment name")

        name in ["PLUSHIE_BINARY_PATH", "PLUSHIE_PACKAGE_DIR", "PLUSHIE_PACKAGE_READY_FILE"] ->
          Mix.raise("Package config start.forward_env must not include launcher-owned variables")

        true ->
          :ok
      end
    end)
  end

  defp validate_payload_path!(name, path) do
    cond do
      path == "" ->
        Mix.raise("Package config #{name} must not be empty")

      Path.type(path) == :absolute ->
        Mix.raise("Package config #{name} must be relative to the package")

      ".." in Path.split(path) ->
        Mix.raise("Package config #{name} must not contain parent traversal")

      true ->
        :ok
    end
  end

  defp validate_payload_archive_inputs!(payload_dir) do
    if File.ls!(payload_dir) == [] do
      raise "payload directory is empty: #{payload_dir}"
    end

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
