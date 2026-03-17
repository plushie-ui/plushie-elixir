defmodule Mix.Tasks.Julep.Preflight do
  @moduledoc """
  Runs all CI checks locally. Exits with a non-zero status on first failure.

  ## Usage

      mix preflight

  ## What it runs

  1. `mix format --check-formatted`
  2. `mix compile --warnings-as-errors`
  3. `mix credo --strict`
  4. `mix test`
  5. `mix dialyzer`
  6. `cargo build` (renderer, if source available)
  7. `cargo test` (renderer, if source available)
  8. `cargo fmt -- --check` (renderer, if source available)
  9. `cargo clippy -- -D warnings` (renderer, if source available)
  """

  use Mix.Task

  @shortdoc "Run all CI checks locally"

  @impl Mix.Task
  def run(_args) do
    renderer_source = Mix.JulepHelpers.renderer_source_path()
    has_renderer_source? = File.dir?(renderer_source)

    steps = [
      {"mix format --check-formatted", fn -> mix_format() end},
      {"mix compile --warnings-as-errors", fn -> mix_compile() end},
      {"mix credo --strict", fn -> mix_credo() end},
      {"mix test", fn -> mix_test() end},
      {"mix dialyzer", fn -> mix_dialyzer() end},
      {"cargo build", fn -> cargo(["build"], renderer_source, has_renderer_source?) end},
      {"cargo test", fn -> cargo(["test"], renderer_source, has_renderer_source?) end},
      {"cargo fmt --check", fn -> cargo_fmt(renderer_source, has_renderer_source?) end},
      {"cargo clippy -D warnings", fn -> cargo_clippy(renderer_source, has_renderer_source?) end}
    ]

    Enum.each(steps, fn {label, fun} ->
      Mix.shell().info([:cyan, "==> ", :reset, label])

      case fun.() do
        :ok ->
          Mix.shell().info([:green, "    PASS", :reset])

        :skip ->
          Mix.shell().info([
            :yellow,
            "    SKIP",
            :reset,
            " (renderer source not found at #{renderer_source})"
          ])

        {:error, code} ->
          Mix.shell().error("    FAIL (exit code #{code})")
          System.halt(code)
      end
    end)

    Mix.shell().info([:green, "\nAll checks passed.", :reset])
  end

  defp mix_format do
    case cmd("mix", ["format", "--check-formatted"]) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp mix_compile do
    case Mix.Task.run("compile", ["--warnings-as-errors"]) do
      {:error, _} -> {:error, 1}
      _ -> :ok
    end
  end

  defp mix_credo do
    case cmd("mix", ["credo", "--strict"]) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp mix_dialyzer do
    case cmd("mix", ["dialyzer"]) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp mix_test do
    case cmd("mix", ["test"]) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp cargo(_args, _source_dir, false), do: :skip

  defp cargo(args, source_dir, true) do
    case cmd("cargo", args, cd: source_dir) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp cargo_fmt(_source_dir, false), do: :skip

  defp cargo_fmt(source_dir, true) do
    case cmd("cargo", ["fmt", "--all", "--", "--check"], cd: source_dir) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp cargo_clippy(_source_dir, false), do: :skip

  defp cargo_clippy(source_dir, true) do
    case cmd("cargo", ["clippy", "--", "-D", "warnings"], cd: source_dir) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp cmd(command, args, opts \\ []) do
    {_, code} =
      System.cmd(command, args, [stderr_to_stdout: true, into: IO.stream(:stdio, :line)] ++ opts)

    code
  end
end
