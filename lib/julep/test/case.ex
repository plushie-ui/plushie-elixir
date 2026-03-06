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

  - `JULEP_TEST_BACKEND` env var (e.g. `headless`, `full`, `sim`)
  - `config :julep, :test_backend, :sim` application config
  - Default: `:sim`
  """

  use ExUnit.CaseTemplate

  alias Julep.Test.Session

  using opts do
    app = Keyword.fetch!(opts, :app)

    quote do
      import Julep.Test.Helpers

      setup _context do
        backend_mod = Julep.Test.Case.resolve_backend()

        # Register extension sim events so custom widget types can be tested
        Julep.Test.ExtensionEvents.register_all()

        session = Session.start(unquote(app), backend: backend_mod)
        Process.put(:julep_test_session, session)

        on_exit(fn ->
          Session.stop(session)
        end)

        {:ok, session: session}
      end
    end
  end

  @backend_map %{
    sim: Julep.Test.Backend.Sim,
    headless: Julep.Test.Backend.Headless,
    full: Julep.Test.Backend.Full
  }

  @doc false
  @spec resolve_backend() :: module()
  def resolve_backend do
    cond do
      env = System.get_env("JULEP_TEST_BACKEND") ->
        Map.get(@backend_map, String.to_existing_atom(env), Julep.Test.Backend.Sim)

      config = Application.get_env(:julep, :test_backend) ->
        Map.get(@backend_map, config, config)

      true ->
        Julep.Test.Backend.Sim
    end
  end
end
