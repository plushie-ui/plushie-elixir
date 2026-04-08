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

  ## Selectors

  All interaction helpers (`click/1`, `find!/1`, `type_text/2`, etc.)
  accept the following selector forms:

  - `"#save"` matches a unique local widget ID
  - `"#form/save"` matches an exact scoped ID
  - `{:text, "Save"}` matches visible text (content, label, value, placeholder)
  - `{:role, "button"}` matches an accessibility role
  - `{:label, "Save"}` matches an accessibility label
  - `:focused` matches the currently focused element

  Bare strings without a `#` prefix are not valid selectors.
  Use `{:text, "Save"}` to match by visible text content.
  """

  use ExUnit.CaseTemplate

  alias Plushie.Test.Session

  using opts do
    app = Keyword.fetch!(opts, :app)

    quote do
      import Plushie.Test.Helpers

      setup _context do
        Plushie.Test.DiagnosticCollector.attach()
        session = Session.start(unquote(app))
        Process.put(:plushie_test_session, session)

        on_exit(fn ->
          diagnostics = Plushie.Test.DiagnosticCollector.flush()
          Plushie.Test.DiagnosticCollector.detach()

          try do
            Session.stop(session)
          catch
            :exit, _ -> :ok
          end

          if diagnostics != [] do
            details =
              Enum.map_join(diagnostics, "\n", fn d ->
                "  - [#{d[:level]}] #{d[:code]}: #{d[:message]}"
              end)

            raise ExUnit.AssertionError,
              message: "Prop validation diagnostics detected during test:\n#{details}"
          end
        end)

        {:ok, session: session}
      end
    end
  end
end
