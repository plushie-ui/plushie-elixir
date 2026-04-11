defmodule Mix.Tasks.Compile.PlushieBinary do
  @moduledoc "Mix compiler that checks for the plushie binary."
  @shortdoc "Check plushie availability"

  use Mix.Task.Compiler

  @manifest "compile.plushie_binary"

  @impl Mix.Task.Compiler
  def manifests, do: [manifest_path()]

  @impl Mix.Task.Compiler
  def clean do
    File.rm(manifest_path())
  end

  @impl Mix.Task.Compiler
  def run(_args) do
    _path = Plushie.Binary.path!()
    {:noop, []}
  rescue
    _ ->
      diagnostic = %Mix.Task.Compiler.Diagnostic{
        file: "plushie-renderer",
        severity: :warning,
        message: Plushie.Binary.not_found_message(),
        position: nil,
        compiler_name: "plushie_binary"
      }

      {:noop, [diagnostic]}
  end

  defp manifest_path do
    Path.join(Mix.Project.manifest_path(), @manifest)
  end
end
