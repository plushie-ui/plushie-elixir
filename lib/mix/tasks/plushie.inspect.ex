defmodule Mix.Tasks.Plushie.Inspect do
  @moduledoc "Inspect a Plushie app's initial view tree without a renderer."
  @shortdoc "Print the initial UI tree as JSON"

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [module_string | _] ->
        module = Module.concat([module_string])

        unless Code.ensure_loaded?(module) do
          Mix.raise("Module #{module_string} not found")
        end

        # Call init to get initial model
        {model, _commands} =
          case module.init([]) do
            {model, cmds} when is_list(cmds) -> {model, cmds}
            {model, %Plushie.Command{} = cmd} -> {model, [cmd]}
            model -> {model, []}
          end

        # Call view to get the tree
        raw_tree = module.view(model)
        tree = Plushie.Tree.normalize(raw_tree)

        # Pretty-print as JSON
        json = Jason.encode!(tree, pretty: true)
        Mix.shell().info(json)

      [] ->
        Mix.raise("Usage: mix plushie.inspect MyApp")
    end
  end
end
