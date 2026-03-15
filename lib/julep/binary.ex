defmodule Julep.Binary do
  @moduledoc "Resolves the path to the julep binary."

  @doc """
  Returns the path to the julep binary.

  Resolution order:
  1. JULEP_RENDERER_PATH environment variable
  2. Application config `:binary_path`
  3. Custom extension build in _build/<env>/julep/target/
  4. Precompiled binary in priv/
  5. Sibling repo at ../julep/target/
  """
  @spec renderer_path() :: String.t()
  def renderer_path do
    path =
      System.get_env("JULEP_RENDERER_PATH") ||
        app_config_path() ||
        custom_build_path() ||
        precompiled_path() ||
        sibling_repo_path() ||
        raise """
        julep binary not found. Searched:
          - $JULEP_RENDERER_PATH (not set)
          - Application config :binary_path (not set)
          - Custom build in _build/
          - Precompiled in priv/bin/
          - Sibling repo at ../julep/target/

        To build from source:
          cd ../julep && cargo build

        To download a precompiled binary:
          mix julep.download
        """

    validate_architecture!(path)
    path
  end

  @doc """
  Validates that the binary at `path` matches the system architecture.

  Runs `file` on the binary and compares the detected architecture against
  `:erlang.system_info(:system_architecture)`. Raises on mismatch. Returns
  `:ok` on match or if the check cannot be performed (e.g. `file` command
  not available, or architecture not recognized).
  """
  @spec validate_architecture!(path :: String.t()) :: :ok
  def validate_architecture!(path) do
    case System.cmd("file", [path], stderr_to_stdout: true) do
      {output, 0} ->
        binary_arch = detect_arch(output)
        sys_arch = system_arch()

        if binary_arch != nil and sys_arch != nil and binary_arch != sys_arch do
          raise """
          Architecture mismatch: julep binary is #{binary_arch} but \
          system is #{sys_arch}.

          Binary: #{path}

          Rebuild for the correct architecture or set JULEP_RENDERER_PATH \
          to the right binary.
          """
        end

        :ok

      _ ->
        # `file` command unavailable or failed -- skip check
        :ok
    end
  rescue
    ErlangError -> :ok
  end

  @doc "Returns the platform-specific binary name."
  @spec binary_name() :: String.t()
  def binary_name do
    os = os_name()
    arch = arch_name()
    ext = if os == "windows", do: ".exe", else: ""
    "julep-#{os}-#{arch}#{ext}"
  end

  @spec detect_arch(file_output :: String.t()) :: :x86_64 | :aarch64 | nil
  defp detect_arch(output) do
    cond do
      String.contains?(output, "x86-64") or String.contains?(output, "x86_64") -> :x86_64
      String.contains?(output, "aarch64") or String.contains?(output, "arm64") -> :aarch64
      true -> nil
    end
  end

  @spec system_arch() :: :x86_64 | :aarch64 | nil
  defp system_arch do
    arch = :erlang.system_info(:system_architecture) |> to_string()

    cond do
      String.contains?(arch, "x86_64") or String.contains?(arch, "amd64") -> :x86_64
      String.contains?(arch, "aarch64") or String.contains?(arch, "arm64") -> :aarch64
      true -> nil
    end
  end

  defp app_config_path do
    case Application.get_env(:julep, :binary_path) do
      nil -> nil
      path when is_binary(path) -> if File.exists?(path), do: path
    end
  rescue
    _ -> nil
  end

  defp custom_build_path do
    for profile <- ["release", "debug"] do
      ext = if os_name() == "windows", do: ".exe", else: ""

      path =
        Path.join([
          Mix.Project.build_path(),
          "julep",
          "target",
          profile,
          "julep#{ext}"
        ])

      if File.exists?(path), do: path
    end
    |> Enum.find(& &1)
  rescue
    _ -> nil
  end

  defp precompiled_path do
    path = Path.join([:code.priv_dir(:julep) |> to_string(), "bin", binary_name()])
    if File.exists?(path), do: path
  rescue
    _ -> nil
  end

  defp sibling_repo_path do
    for release? <- [true, false] do
      path = Mix.JulepHelpers.renderer_binary_path(release?)
      if File.exists?(path), do: path
    end
    |> Enum.find(& &1)
  rescue
    _ -> nil
  end

  defp os_name do
    case :os.type() do
      {:unix, :linux} -> "linux"
      {:unix, :darwin} -> "darwin"
      {:win32, _} -> "windows"
      {_, os} -> to_string(os)
    end
  end

  defp arch_name do
    arch = :erlang.system_info(:system_architecture) |> to_string()

    cond do
      String.contains?(arch, "x86_64") or String.contains?(arch, "amd64") -> "x86_64"
      String.contains?(arch, "aarch64") or String.contains?(arch, "arm64") -> "aarch64"
      String.contains?(arch, "arm") -> "arm"
      true -> "unknown"
    end
  end
end
