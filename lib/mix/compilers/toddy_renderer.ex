defmodule Mix.Tasks.Compile.ToddyRenderer do
  @moduledoc "Mix compiler that checks for the toddy binary."
  @shortdoc "Check toddy availability"

  use Mix.Task.Compiler

  @manifest "compile.toddy_renderer"

  @impl true
  def manifests, do: [manifest_path()]

  @impl true
  def clean do
    File.rm(manifest_path())
  end

  @impl true
  def run(_args) do
    _path = Toddy.Binary.renderer_path()
    {:noop, []}
  rescue
    _ ->
      diagnostic = %Mix.Task.Compiler.Diagnostic{
        file: "toddy",
        severity: :warning,
        message: """
        toddy binary not found.

        The renderer is now a separate repository. To build it:
          cd ../toddy && cargo build

        Or set TODDY_RENDERER_PATH to an existing binary.
        Or run: mix toddy.download
        """,
        position: nil,
        compiler_name: "toddy_renderer"
      }

      {:noop, [diagnostic]}
  end

  defp manifest_path do
    Path.join(Mix.Project.manifest_path(), @manifest)
  end
end
