defmodule Plushie.Binary do
  @moduledoc """
  Resolves the path to the plushie binary.

  Resolution order for `path!/0`:

  1. `PLUSHIE_BINARY_PATH` environment variable
  2. Application config `:binary_path`
  3. Custom extension build in `_build/<env>/plushie/target/`
  4. Precompiled binary in `priv/bin/`

  Steps 1 and 2 are explicit configuration -- if set but pointing to a
  missing file, they raise immediately rather than falling through. Steps
  3 and 4 are implicit discovery and silently try the next option.
  """

  @doc """
  Standard instructions for resolving a missing plushie binary.

  Used by the compiler, test helper, and error messages to provide
  consistent guidance.
  """
  @spec not_found_message() :: String.t()
  def not_found_message do
    """
    plushie binary not found.

    To download a precompiled binary:
      mix plushie.download

    To build from source:
      mix plushie.build

    To use an existing binary:
      export PLUSHIE_BINARY_PATH=/path/to/plushie

    See the project README for setup instructions.\
    """
  end

  @doc """
  Returns the path to the plushie binary.

  Raises with `not_found_message/0` if no binary can be resolved, or
  with a specific message if an explicitly configured path doesn't exist.
  """
  @spec path!() :: String.t()
  def path! do
    path =
      env_path() ||
        app_config_path() ||
        custom_build_path() ||
        precompiled_path() ||
        raise not_found_message()

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
          Architecture mismatch: plushie binary is #{binary_arch} but \
          system is #{sys_arch}.

          Binary: #{path}

          Rebuild for the correct architecture or set PLUSHIE_BINARY_PATH \
          to the right binary.
          """
        end

        :ok

      _ ->
        :ok
    end
  rescue
    # `file` command not found on this system
    ErlangError -> :ok
  end

  @doc """
  Returns the platform-specific binary name for downloads.

  Format: `plushie-{os}-{arch}` (e.g. `plushie-linux-x86_64`).
  """
  @spec download_name() :: String.t()
  def download_name do
    os = os_name()
    arch = arch_name()
    ext = if os == "windows", do: ".exe", else: ""
    "plushie-#{os}-#{arch}#{ext}"
  end

  @doc """
  Returns the binary name for custom extension builds.

  Derived from the Mix project app name by default, overridable via config:

      config :plushie, :build_name, "my-custom-plushie"

  For a project named `:my_dashboard`, the default is `my-dashboard-plushie`.
  """
  @spec build_name() :: String.t()
  def build_name do
    case Application.get_env(:plushie, :build_name) do
      nil ->
        app = Mix.Project.config()[:app] |> Atom.to_string() |> String.replace("_", "-")
        "#{app}-plushie"

      name when is_binary(name) ->
        name

      other ->
        raise "config :plushie, :build_name must be a string, got: #{inspect(other)}"
    end
  end

  # -- Resolution steps --------------------------------------------------------

  @spec env_path() :: String.t() | nil
  defp env_path do
    case System.get_env("PLUSHIE_BINARY_PATH") do
      nil ->
        nil

      path ->
        unless File.exists?(path) do
          raise """
          PLUSHIE_BINARY_PATH is set to #{path} but the file does not exist.

          Check the path or unset the variable to use automatic resolution.
          """
        end

        path
    end
  end

  @spec app_config_path() :: String.t() | nil
  defp app_config_path do
    case Application.get_env(:plushie, :binary_path) do
      nil ->
        nil

      path when is_binary(path) ->
        unless File.exists?(path) do
          raise """
          config :plushie, :binary_path is set to #{inspect(path)} but the file does not exist.

          Check the path in your config or remove it to use automatic resolution.
          """
        end

        path

      other ->
        raise "config :plushie, :binary_path must be a string, got: #{inspect(other)}"
    end
  end

  @spec custom_build_path() :: String.t() | nil
  defp custom_build_path do
    bin_name = build_name()

    for profile <- ["release", "debug"] do
      ext = if os_name() == "windows", do: ".exe", else: ""

      path =
        Path.join([
          Mix.Project.build_path(),
          "plushie",
          "target",
          profile,
          "#{bin_name}#{ext}"
        ])

      if File.exists?(path), do: path
    end
    |> Enum.find(& &1)
  end

  @spec precompiled_path() :: String.t() | nil
  defp precompiled_path do
    path = Path.join([:code.priv_dir(:plushie) |> to_string(), "bin", download_name()])
    if File.exists?(path), do: path
  end

  # -- Platform detection ------------------------------------------------------

  @spec detect_arch(output :: String.t()) :: :x86_64 | :aarch64 | nil
  defp detect_arch(output) do
    cond do
      String.contains?(output, "x86-64") or String.contains?(output, "x86_64") or
          String.contains?(output, "amd64") ->
        :x86_64

      String.contains?(output, "aarch64") or String.contains?(output, "arm64") ->
        :aarch64

      true ->
        nil
    end
  end

  @spec system_arch() :: :x86_64 | :aarch64 | nil
  defp system_arch, do: detect_arch(:erlang.system_info(:system_architecture) |> to_string())

  @spec os_name() :: String.t()
  defp os_name do
    case :os.type() do
      {:unix, :linux} -> "linux"
      {:unix, :darwin} -> "darwin"
      {:win32, _} -> "windows"
      {_, os} -> to_string(os)
    end
  end

  @spec arch_name() :: String.t()
  defp arch_name do
    case system_arch() do
      :x86_64 -> "x86_64"
      :aarch64 -> "aarch64"
      nil -> "unknown"
    end
  end
end
