defmodule Julep.Binary do
  @moduledoc "Resolves the path to the julep_gui renderer binary."

  @doc """
  Returns the path to the julep_gui binary.

  Resolution order:
  1. JULEP_RENDERER_PATH environment variable
  2. Precompiled binary in priv/
  3. Development build in native/julep_gui/target/
  """
  @spec renderer_path() :: String.t()
  def renderer_path do
    System.get_env("JULEP_RENDERER_PATH") ||
      precompiled_path() ||
      dev_build_path() ||
      raise "julep_gui binary not found. Run `mix julep.build` or `mix julep.download`."
  end

  @doc "Returns the platform-specific binary name."
  @spec binary_name() :: String.t()
  def binary_name do
    os = os_name()
    arch = arch_name()
    ext = if os == "windows", do: ".exe", else: ""
    "julep_gui-#{os}-#{arch}#{ext}"
  end

  defp precompiled_path do
    path = Path.join([:code.priv_dir(:julep) |> to_string(), "bin", binary_name()])
    if File.exists?(path), do: path
  rescue
    _ -> nil
  end

  defp dev_build_path do
    # Try release first, then debug
    for profile <- ["release", "debug"] do
      ext = if os_name() == "windows", do: ".exe", else: ""
      path = Path.join([File.cwd!(), "native", "julep_gui", "target", profile, "julep_gui#{ext}"])
      if File.exists?(path), do: path
    end
    |> Enum.find(& &1)
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
