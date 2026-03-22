defmodule Plushie.Test.Case do
  @moduledoc """
  ExUnit case template for testing Plushie apps.

  ## Usage

      defmodule MyApp.CounterTest do
        use Plushie.Test.Case, app: MyApp.Counter

        test "clicking increment updates counter" do
          click("#increment")
          assert find!("#count") |> text() == "1"
        end
      end

  ## Backend selection

  The backend is resolved from environment or application config:

  - `PLUSHIE_TEST_BACKEND` env var (e.g. `mock`, `headless`, `windowed`)
  - `config :plushie, :test_backend, :mock` application config
  - Default: `:mock` (runs the plushie binary in `--mock` mode, sessions pooled)

  The mock backend shares a single renderer process across tests
  via `Plushie.Test.SessionPool`. The renderer mode (mock vs headless)
  is set when the pool is started, not per-backend. See
  `Plushie.Test.SessionPool` for details.
  """

  use ExUnit.CaseTemplate

  alias Plushie.Test.Session

  using opts do
    app = Keyword.fetch!(opts, :app)

    quote do
      import Plushie.Test.Helpers

      setup _context do
        backend_mod = Plushie.Test.Case.resolve_backend()
        backend_opts = Plushie.Test.Case.backend_opts(backend_mod)

        session = Session.start(unquote(app), [{:backend, backend_mod} | backend_opts])
        Process.put(:plushie_test_session, session)

        on_exit(fn ->
          try do
            Session.stop(session)
          catch
            :exit, _ -> :ok
          end
        end)

        {:ok, session: session}
      end
    end
  end

  @backend_map %{
    mock: Plushie.Test.Backend.MockRenderer,
    headless: Plushie.Test.Backend.Headless,
    windowed: Plushie.Test.Backend.Windowed
  }

  @doc false
  @spec backend_opts(module()) :: keyword()
  def backend_opts(Plushie.Test.Backend.MockRenderer), do: []

  def backend_opts(_non_pooled) do
    # Non-pooled backends (headless, windowed) need the renderer path
    # directly since they spawn their own renderer process.
    case Application.get_env(:plushie, :test_binary_path) do
      nil -> [renderer: Plushie.Binary.path!()]
      path -> [renderer: path]
    end
  end

  @doc false
  @spec resolve_backend() :: module()
  def resolve_backend do
    cond do
      env = System.get_env("PLUSHIE_TEST_BACKEND") ->
        Map.get(@backend_map, String.to_existing_atom(env), Plushie.Test.Backend.MockRenderer)

      config = Application.get_env(:plushie, :test_backend) ->
        Map.get(@backend_map, config, config)

      true ->
        Plushie.Test.Backend.MockRenderer
    end
  end
end
