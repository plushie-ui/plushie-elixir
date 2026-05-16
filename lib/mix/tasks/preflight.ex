defmodule Mix.Tasks.Preflight do
  @moduledoc """
  Runs all CI checks locally. Exits with a non-zero status on first failure.

  ## Usage

      mix preflight

  ## What it runs

  1. Renderer rebuild (when `PLUSHIE_RUST_SOURCE_PATH` is set)
  2. `mix format --check-formatted`
  3. `mix compile --warnings-as-errors`
  4. `mix credo --strict`
  5. `mix test`
  6. `mix test` (headless backend)
  7. `mix docs --warnings-as-errors`
  8. `mix dialyzer`

  ## Renderer freshness

  Tests exercise the real renderer binary, so a stale binary hides real
  bugs and surfaces phantom ones. When `PLUSHIE_RUST_SOURCE_PATH` is set
  to a plushie-rust checkout, the first preflight step runs
  `cargo-plushie tools sync` from the checkout, which builds and installs
  all three managed tool files (`bin/plushie`, `bin/plushie-renderer`,
  `bin/plushie-launcher`). `PLUSHIE_BINARY_PATH` is then set to the
  project-local `bin/plushie-renderer` so all subsequent steps run against
  the fresh binary. Without `PLUSHIE_RUST_SOURCE_PATH` the existing
  binary resolution (env -> config -> custom build -> downloaded) is
  used unchanged.
  """

  use Mix.Task

  @shortdoc "Run all CI checks locally"
  @port_idle_timeout_ms :timer.minutes(15)

  @typep step_result :: :ok | {:error, pos_integer()}

  @impl Mix.Task
  def run(_args) do
    rebuild_step =
      case Mix.PlushieHelpers.source_path() do
        nil -> []
        source -> [{"cargo-plushie tools sync", fn -> rebuild_renderer(source) end}]
      end

    steps =
      rebuild_step ++
        [
          {"mix format --check-formatted", fn -> mix_cmd(["format", "--check-formatted"]) end},
          {"mix compile --warnings-as-errors", fn -> mix_compile() end},
          {"mix credo --strict", fn -> mix_cmd(["credo", "--strict"]) end},
          {"mix test", fn -> mix_cmd(["test"]) end},
          {"mix test (headless)", fn -> mix_test_headless() end},
          {"mix docs --warnings-as-errors", fn -> mix_docs() end},
          {"mix dialyzer", fn -> mix_cmd(["dialyzer"]) end}
        ]

    Enum.each(steps, fn {label, fun} ->
      Mix.shell().info([:cyan, "==> ", :reset, label])

      case fun.() do
        :ok ->
          Mix.shell().info([:green, "    PASS", :reset])

        {:error, code} ->
          Mix.shell().error("    FAIL (exit code #{code})")
          System.halt(code)
      end
    end)

    Mix.shell().info([:green, "\nAll checks passed.", :reset])
  end

  # Syncs all managed tools from a local source checkout via cargo-plushie
  # and exports PLUSHIE_BINARY_PATH to bin/plushie-renderer so the rest of
  # preflight runs against the fresh binary. cargo-plushie picks up
  # `.cargo/config.toml` from the workspace, which carries the local
  # plushie-iced `[patch.crates-io]` overrides.
  @spec rebuild_renderer(String.t()) :: step_result()
  defp rebuild_renderer(source) do
    expanded = Path.expand(source)
    manifest = Path.join(expanded, "Cargo.toml")

    if File.exists?(manifest) do
      run_cargo_build(expanded)
    else
      Mix.shell().error("    PLUSHIE_RUST_SOURCE_PATH=#{source} but no Cargo.toml at #{manifest}")
      {:error, 1}
    end
  end

  @spec run_cargo_build(String.t()) :: step_result()
  defp run_cargo_build(workspace) do
    manifest = Path.join(workspace, "Cargo.toml")
    version = Plushie.Binary.plushie_rust_version()

    args = [
      "run",
      "--manifest-path",
      manifest,
      "-p",
      "cargo-plushie",
      "--bin",
      "plushie",
      "--release",
      "--quiet",
      "--",
      "tools",
      "sync",
      "--required-version",
      version
    ]

    case stream_cmd("cargo", args) do
      0 -> verify_and_export_managed_tools()
      code -> {:error, code}
    end
  end

  @spec verify_and_export_managed_tools() :: step_result()
  defp verify_and_export_managed_tools do
    dir = Plushie.Binary.download_dir()
    renderer = Path.join(dir, Plushie.Binary.download_name())
    tool = Path.join(dir, Plushie.Binary.tool_name())
    launcher = Path.join(dir, Mix.PlushiePackage.launcher_name())

    missing = Enum.reject([tool, renderer, launcher], &File.regular?/1)

    if missing != [] do
      Enum.each(missing, fn path ->
        Mix.shell().error("    tools sync succeeded but #{path} is missing")
      end)

      {:error, 1}
    else
      System.put_env("PLUSHIE_BINARY_PATH", renderer)
      :ok
    end
  end

  # -- Steps -------------------------------------------------------------------

  @spec mix_compile() :: step_result()
  defp mix_compile do
    case Mix.Task.run("compile", ["--warnings-as-errors", "--return-errors"]) do
      {:error, _} -> {:error, 1}
      _ -> :ok
    end
  end

  @spec mix_docs() :: step_result()
  defp mix_docs do
    exit_code_to_result(
      stream_cmd("mix", ["docs", "--warnings-as-errors"], env: [{"MIX_ENV", "dev"}])
    )
  end

  @spec mix_test_headless() :: step_result()
  defp mix_test_headless do
    exit_code_to_result(stream_cmd("mix", ["test"], env: [{"PLUSHIE_TEST_BACKEND", "headless"}]))
  end

  @spec mix_cmd([String.t()]) :: step_result()
  defp mix_cmd(args), do: exit_code_to_result(stream_cmd("mix", args))

  # -- Subprocess streaming ----------------------------------------------------

  # Streams a subprocess to the terminal, returning its exit code.
  # Uses Port directly instead of System.cmd because some test output
  # can contain raw bytes (non-UTF-8). :file.write/2 bypasses encoding
  # validation.
  @spec stream_cmd(String.t(), [String.t()], keyword()) :: non_neg_integer()
  defp stream_cmd(command, args, opts \\ []) do
    executable =
      System.find_executable(command) ||
        raise "#{command} not found in PATH"

    port_opts = [:binary, :exit_status, :stderr_to_stdout, {:args, args}]

    port_opts =
      case opts[:env] do
        nil ->
          port_opts

        env ->
          [
            {:env, Enum.map(env, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)}
            | port_opts
          ]
      end

    port_opts =
      case opts[:cd] do
        nil -> port_opts
        cd -> [{:cd, String.to_charlist(cd)} | port_opts]
      end

    port = Port.open({:spawn_executable, executable}, port_opts)
    drain_port(port)
  end

  @spec drain_port(port()) :: non_neg_integer()
  defp drain_port(port) do
    receive do
      {^port, {:data, data}} ->
        :file.write(:standard_io, data)
        drain_port(port)

      {^port, {:exit_status, code}} ->
        code

      {^port, :closed} ->
        1
    after
      @port_idle_timeout_ms ->
        close_port(port)
        Mix.shell().error("    process produced no output or exit status before timeout")
        124
    end
  end

  @spec close_port(port()) :: :ok
  defp close_port(port) do
    Port.close(port)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @spec exit_code_to_result(non_neg_integer()) :: step_result()
  defp exit_code_to_result(0), do: :ok
  defp exit_code_to_result(code), do: {:error, code}
end
