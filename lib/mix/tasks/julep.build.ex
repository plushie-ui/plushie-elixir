defmodule Mix.Tasks.Julep.Build do
  @moduledoc "Build the julep_gui renderer binary."
  @shortdoc "Build the julep_gui renderer"

  use Mix.Task

  @impl true
  def run(args) do
    manifest_path = Path.join([File.cwd!(), "native", "julep_gui", "Cargo.toml"])

    unless File.exists?(manifest_path) do
      Mix.raise("Cargo.toml not found at #{manifest_path}")
    end

    release? = "--release" in args

    cmd_args = ["build", "--manifest-path", manifest_path]
    cmd_args = if release?, do: cmd_args ++ ["--release"], else: cmd_args
    cmd_args = cmd_args ++ feature_flags()

    Mix.shell().info("Building julep_gui#{if release?, do: " (release)", else: ""}...")

    case System.cmd("cargo", cmd_args, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info("Build succeeded.")
        if "--verbose" in args, do: Mix.shell().info(output)
        :ok

      {output, status} ->
        Mix.shell().error("Build failed (exit code #{status}):")
        Mix.shell().error(output)
        Mix.raise("cargo build failed")
    end
  end

  defp feature_flags do
    case Application.get_env(:julep, :iced_features, :all) do
      :all ->
        # Default Cargo features include builtin-all -- no extra flags needed.
        []

      features when is_list(features) ->
        # Build with only the requested widget features plus the non-widget defaults.
        widget_features = Enum.map(features, &Julep.Features.cargo_feature_name/1)
        all_features = widget_features ++ ["dialogs", "clipboard", "notifications"]
        ["--no-default-features", "--features", Enum.join(all_features, ",")]
    end
  end
end
