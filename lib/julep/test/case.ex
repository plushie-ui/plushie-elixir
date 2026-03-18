defmodule Julep.Test.Case do
  @moduledoc """
  ExUnit case template for testing Julep apps.

  ## Usage

      defmodule MyApp.CounterTest do
        use Julep.Test.Case, app: MyApp.Counter

        test "clicking increment updates counter" do
          click("#increment")
          assert find!("#count") |> text() == "1"
        end
      end

  ## Backend selection

  The backend is resolved from environment or application config:

  - `JULEP_TEST_BACKEND` env var (e.g. `headless`, `full`, `pooled_mock`, `pooled_headless`)
  - `config :julep, :test_backend, :pooled_mock` application config
  - Default: `:pooled_mock` (pooled backend with mock renderer)
  """

  use ExUnit.CaseTemplate

  alias Julep.Test.Session

  using opts do
    app = Keyword.fetch!(opts, :app)

    quote do
      import Julep.Test.Helpers

      setup _context do
        backend_mod = Julep.Test.Case.resolve_backend()

        session = Session.start(unquote(app), backend: backend_mod)
        Process.put(:julep_test_session, session)

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
    pooled_mock: Julep.Test.Backend.Pooled,
    pooled_headless: Julep.Test.Backend.Pooled,
    headless: Julep.Test.Backend.Headless,
    full: Julep.Test.Backend.Full
  }

  @doc false
  @spec resolve_backend() :: module()
  def resolve_backend do
    cond do
      env = System.get_env("JULEP_TEST_BACKEND") ->
        Map.get(@backend_map, String.to_existing_atom(env), Julep.Test.Backend.Pooled)

      config = Application.get_env(:julep, :test_backend) ->
        Map.get(@backend_map, config, config)

      true ->
        Julep.Test.Backend.Pooled
    end
  end
end
