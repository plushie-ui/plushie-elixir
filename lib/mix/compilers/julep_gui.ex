defmodule Mix.Tasks.Compile.JulepGui do
  @moduledoc "Mix compiler that builds the julep_gui Rust renderer."
  @shortdoc "Compile julep_gui (cargo build)"

  use Mix.Task.Compiler

  @manifest "compile.julep_gui"
  @native_dir Path.join(~w(native julep_gui))

  @impl true
  def manifests, do: [manifest_path()]

  @impl true
  def clean do
    File.rm(manifest_path())
  end

  @impl true
  def run(_args) do
    manifest_path = Path.join([File.cwd!(), @native_dir, "Cargo.toml"])

    unless File.exists?(manifest_path) do
      Mix.raise("Cargo.toml not found at #{manifest_path}")
    end

    sources = rust_sources()
    last_mtime = read_manifest()

    if needs_rebuild?(sources, last_mtime) do
      compile(manifest_path, sources)
    else
      {:noop, []}
    end
  end

  defp compile(manifest_path, sources) do
    Mix.shell().info("Compiling julep_gui...")

    cmd_args = ["build", "--manifest-path", manifest_path]

    case System.cmd("cargo", cmd_args, stderr_to_stdout: true) do
      {_output, 0} ->
        write_manifest(max_mtime(sources))
        {:ok, []}

      {output, _status} ->
        # Emit as a single diagnostic so mix shows it properly
        diagnostic = %Mix.Task.Compiler.Diagnostic{
          file: manifest_path,
          severity: :error,
          message: "cargo build failed:\n#{output}",
          position: nil,
          compiler_name: "julep_gui"
        }

        {:error, [diagnostic]}
    end
  end

  defp rust_sources do
    Path.wildcard(Path.join(@native_dir, "{src,tests}/**/*.rs")) ++
      [Path.join(@native_dir, "Cargo.toml"), Path.join(@native_dir, "Cargo.lock")]
  end

  defp needs_rebuild?(sources, nil), do: sources != []

  defp needs_rebuild?(sources, last_mtime) do
    max_mtime(sources) > last_mtime
  end

  defp max_mtime([]), do: 0

  defp max_mtime(sources) do
    sources
    |> Enum.map(&file_mtime/1)
    |> Enum.max()
  end

  defp file_mtime(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} -> mtime
      _ -> 0
    end
  end

  defp manifest_path do
    Path.join(Mix.Project.manifest_path(), @manifest)
  end

  defp read_manifest do
    case File.read(manifest_path()) do
      {:ok, contents} ->
        case Integer.parse(String.trim(contents)) do
          {mtime, ""} -> mtime
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp write_manifest(mtime) do
    File.mkdir_p!(Path.dirname(manifest_path()))
    File.write!(manifest_path(), Integer.to_string(mtime))
  end
end
