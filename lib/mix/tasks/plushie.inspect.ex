defmodule Mix.Tasks.Plushie.Inspect do
  @moduledoc """
  Inspect a Plushie app's UI tree.

  Without `--script`, shows the initial view tree (no renderer needed).
  With `--script`, starts a test session, runs the script, and shows
  the tree after execution.

  ## Usage

      mix plushie.inspect MyApp
      mix plushie.inspect MyApp --script test/fixtures/setup.plushie
  """
  @shortdoc "Print the UI tree as JSON"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, strict: [script: :string])

    case positional do
      [module_string | _] ->
        Mix.Task.run("app.start")

        module = Module.concat([module_string])

        unless Code.ensure_loaded?(module) do
          Mix.raise("Module #{module_string} not found")
        end

        case Keyword.get(opts, :script) do
          nil ->
            inspect_initial(module)

          script_path ->
            inspect_after_script(module, script_path)
        end

      [] ->
        Mix.raise("Usage: mix plushie.inspect MyApp [--script FILE]")
    end
  end

  defp inspect_initial(module) do
    {model, _commands} =
      case module.init([]) do
        {model, cmds} when is_list(cmds) -> {model, cmds}
        {model, %Plushie.Command{} = cmd} -> {model, [cmd]}
        model -> {model, []}
      end

    raw_tree = module.view(model)
    tree = Plushie.Tree.normalize(raw_tree)
    json = Jason.encode!(tree, pretty: true)
    Mix.shell().info(json)
  end

  defp inspect_after_script(module, script_path) do
    unless File.exists?(script_path) do
      Mix.raise("Script file not found: #{script_path}")
    end

    input = File.read!(script_path)

    case Plushie.Automation.File.parse(input) do
      {:ok, script} ->
        # Override the script's app with the one from the command line
        script = %{script | header: %{script.header | app: module}}

        case Plushie.Automation.Runner.run(script, replay: true) do
          :ok ->
            Mix.shell().info("Script completed successfully.")

          {:error, failures} ->
            Mix.shell().error("Script had #{length(failures)} failure(s):")

            for {{action, selector, expected}, message} <- failures do
              Mix.shell().error(
                "  #{action} #{inspect(selector)} #{inspect(expected)}: #{message}"
              )
            end
        end

      {:error, reason} ->
        Mix.raise("Failed to parse script: #{inspect(reason)}")
    end
  end
end
