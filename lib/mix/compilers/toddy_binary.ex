defmodule Mix.Tasks.Compile.ToddyBinary do
  @moduledoc "Mix compiler that checks for the toddy binary."
  @shortdoc "Check toddy availability"

  use Mix.Task.Compiler

  @manifest "compile.toddy_binary"

  @impl true
  def manifests, do: [manifest_path()]

  @impl true
  def clean do
    File.rm(manifest_path())
  end

  @impl true
  def run(_args) do
    _path = Toddy.Binary.path!()
    {:noop, []}
  rescue
    _ ->
      diagnostic = %Mix.Task.Compiler.Diagnostic{
        file: "toddy",
        severity: :warning,
        message: Toddy.Binary.not_found_message(),
        position: nil,
        compiler_name: "toddy_binary"
      }

      {:noop, [diagnostic]}
  end

  defp manifest_path do
    Path.join(Mix.Project.manifest_path(), @manifest)
  end
end
