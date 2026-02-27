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

  The backend determines how deeply interactions are tested:

  | Priority | Source | Example |
  |----------|--------|---------|
  | 1 | Per-test tag | `@tag backend: :headless` |
  | 2 | Module option | `use Julep.Test.Case, app: MyApp, backend: :headless` |
  | 3 | Environment variable | `JULEP_TEST_BACKEND=headless` |
  | 4 | Application config | `config :julep, :test_backend, :sim` |
  | 5 | Default | `:sim` |
  """

  use ExUnit.CaseTemplate

  alias Julep.Test.Session

  using opts do
    app = Keyword.fetch!(opts, :app)
    default_backend = Keyword.get(opts, :backend)

    quote do
      import Julep.Test.Helpers

      setup context do
        backend_mod =
          Julep.Test.Case.resolve_backend(
            context[:backend],
            unquote(default_backend)
          )

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
  @spec resolve_backend(
          tag_backend :: atom() | module() | nil,
          module_backend :: atom() | module() | nil
        ) :: module()
  def resolve_backend(tag_backend, module_backend) do
    cond do
      tag_backend ->
        Map.get(@backend_map, tag_backend, tag_backend)

      module_backend ->
        Map.get(@backend_map, module_backend, module_backend)

      env = System.get_env("JULEP_TEST_BACKEND") ->
        Map.get(@backend_map, String.to_existing_atom(env), Julep.Test.Backend.Sim)

      config = Application.get_env(:julep, :test_backend) ->
        Map.get(@backend_map, config, config)

      true ->
        Julep.Test.Backend.Sim
    end
  end
end
