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

  - `JULEP_TEST_BACKEND` env var (e.g. `headless`, `full`, `mock`)
  - `config :julep, :test_backend, :mock` application config
  - Default: `:mock`
  """

  use ExUnit.CaseTemplate

  alias Julep.Test.Session

  using opts do
    app = Keyword.fetch!(opts, :app)

    quote do
      import ExUnit.CaptureLog
      import Julep.Test.Helpers

      setup _context do
        backend_mod = Julep.Test.Case.resolve_backend()

        # Register extension mock events so custom widget types can be tested.
        # capture_log suppresses collision warnings from test-only extensions.
        capture_log(fn -> Julep.Test.ExtensionEvents.register_all() end)

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
    mock: Julep.Test.Backend.Mock,
    headless: Julep.Test.Backend.Headless,
    full: Julep.Test.Backend.Full
  }

  @doc false
  @spec resolve_backend() :: module()
  def resolve_backend do
    cond do
      env = System.get_env("JULEP_TEST_BACKEND") ->
        Map.get(@backend_map, String.to_existing_atom(env), Julep.Test.Backend.Mock)

      config = Application.get_env(:julep, :test_backend) ->
        Map.get(@backend_map, config, config)

      true ->
        Julep.Test.Backend.Mock
    end
  end
end
