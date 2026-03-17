defmodule Mix.Tasks.Compile.JulepRenderer do
  @moduledoc "Mix compiler that checks for the julep binary."
  @shortdoc "Check julep availability"

  use Mix.Task.Compiler

  @manifest "compile.julep_renderer"

  @impl true
  def manifests, do: [manifest_path()]

  @impl true
  def clean do
    File.rm(manifest_path())
  end

  @impl true
  def run(_args) do
    _path = Julep.Binary.renderer_path()
    {:noop, []}
  rescue
    _ ->
      diagnostic = %Mix.Task.Compiler.Diagnostic{
        file: "julep",
        severity: :warning,
        message: """
        julep binary not found.

        The renderer is now a separate repository. To build it:
          cd ../julep && cargo build

        Or set JULEP_RENDERER_PATH to an existing binary.
        Or run: mix julep.download
        """,
        position: nil,
        compiler_name: "julep_renderer"
      }

      {:noop, [diagnostic]}
  end

  defp manifest_path do
    Path.join(Mix.Project.manifest_path(), @manifest)
  end
end
