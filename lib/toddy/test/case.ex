defmodule Toddy.Test.Case do
  @moduledoc """
  ExUnit case template for testing Toddy apps.

  ## Usage

      defmodule MyApp.CounterTest do
        use Toddy.Test.Case, app: MyApp.Counter

        test "clicking increment updates counter" do
          click("#increment")
          assert find!("#count") |> text() == "1"
        end
      end

  ## Backend selection

  The backend is resolved from environment or application config:

  - `TODDY_TEST_BACKEND` env var (e.g. `pooled_mock`, `headless`, `windowed`)
  - `config :toddy, :test_backend, :pooled_mock` application config
  - Default: `:pooled_mock` (pooled backend with mock renderer)

  The pooled backend shares a single renderer process across tests
  via `Toddy.Test.SessionPool`. The renderer mode (mock vs headless)
  is set when the pool is started, not per-backend. See
  `Toddy.Test.SessionPool` for details.
  """

  use ExUnit.CaseTemplate

  alias Toddy.Test.Session

  using opts do
    app = Keyword.fetch!(opts, :app)

    quote do
      import Toddy.Test.Helpers

      setup _context do
        backend_mod = Toddy.Test.Case.resolve_backend()

        session = Session.start(unquote(app), backend: backend_mod)
        Process.put(:toddy_test_session, session)

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
    pooled_mock: Toddy.Test.Backend.Pooled,
    headless: Toddy.Test.Backend.Headless,
    windowed: Toddy.Test.Backend.Windowed
  }

  @doc false
  @spec resolve_backend() :: module()
  def resolve_backend do
    cond do
      env = System.get_env("TODDY_TEST_BACKEND") ->
        Map.get(@backend_map, String.to_existing_atom(env), Toddy.Test.Backend.Pooled)

      config = Application.get_env(:toddy, :test_backend) ->
        Map.get(@backend_map, config, config)

      true ->
        Toddy.Test.Backend.Pooled
    end
  end
end
