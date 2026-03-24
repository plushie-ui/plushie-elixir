defmodule Plushie.Test.Case do
  @moduledoc """
  ExUnit case template for testing Plushie apps.

  Starts a real Plushie app (Runtime + Bridge) connected to the shared
  renderer session pool before each test, and stops it on exit.

  ## Usage

      defmodule MyApp.CounterTest do
        use Plushie.Test.Case, app: MyApp.Counter

        test "clicking increment updates counter" do
          click("#increment")
          assert find!("#count") |> text() == "1"
        end
      end
  """

  use ExUnit.CaseTemplate

  alias Plushie.Test.Session

  using opts do
    app = Keyword.fetch!(opts, :app)

    quote do
      import Plushie.Test.Helpers

      setup _context do
        session = Session.start(unquote(app))
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
end
