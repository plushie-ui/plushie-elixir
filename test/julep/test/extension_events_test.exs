defmodule Julep.Test.ExtensionEventsTest do
  use ExUnit.Case, async: false

  alias Julep.Event.Widget

  alias Julep.Test.Element
  alias Julep.Test.EventMap
  alias Julep.Test.ExtensionEvents

  setup do
    on_exit(fn -> ExtensionEvents.clear() end)
    :ok
  end

  # -- Mock extensions --------------------------------------------------------

  defmodule TerminalExtension do
    @behaviour Julep.Extension

    @impl true
    def native_crate, do: "native/terminal"

    @impl true
    def rust_constructor, do: "terminal::Extension::new()"

    @impl true
    def type_names, do: [:terminal]

    @impl true
    def sim_events(:click, %Element{id: id}, []),
      do: {:ok, {:terminal_focus, id}}

    def sim_events(:input, %Element{id: id}, [text]),
      do: {:ok, {:terminal_input, id, text}}

    def sim_events(_verb, _element, _args),
      do: :not_handled
  end

  defmodule ChartExtension do
    @behaviour Julep.Extension

    @impl true
    def native_crate, do: "native/chart"

    @impl true
    def rust_constructor, do: "chart::Extension::new()"

    @impl true
    def type_names, do: [:bar_chart, :line_chart]

    @impl true
    def sim_events(:click, %Element{id: id, props: props}, []) do
      series = props["series"] || "default"
      {:ok, {:chart_click, id, series}}
    end

    def sim_events(_verb, _element, _args),
      do: :not_handled
  end

  # Extension without sim_events callback
  defmodule MinimalExtension do
    @behaviour Julep.Extension

    @impl true
    def native_crate, do: "native/minimal"

    @impl true
    def rust_constructor, do: "minimal::Extension::new()"

    @impl true
    def type_names, do: [:minimal_widget]
  end

  # -- Helpers ----------------------------------------------------------------

  defp el(id, type, props \\ %{}) do
    %Element{id: id, type: type, props: props, children: []}
  end

  # -- register/1 -------------------------------------------------------------

  describe "register/1" do
    test "registers module for each type name" do
      ExtensionEvents.register(TerminalExtension)

      result = ExtensionEvents.dispatch(:click, el("t1", "terminal"), [])
      assert {:ok, {:terminal_focus, "t1"}} = result
    end

    test "registers multiple type names for one module" do
      ExtensionEvents.register(ChartExtension)

      assert {:ok, {:chart_click, "c1", "default"}} =
               ExtensionEvents.dispatch(:click, el("c1", "bar_chart"), [])

      assert {:ok, {:chart_click, "c2", "default"}} =
               ExtensionEvents.dispatch(:click, el("c2", "line_chart"), [])
    end

    test "re-registering the same module is idempotent" do
      ExtensionEvents.register(TerminalExtension)
      ExtensionEvents.register(TerminalExtension)

      assert {:ok, {:terminal_focus, "t1"}} =
               ExtensionEvents.dispatch(:click, el("t1", "terminal"), [])
    end

    test "raises on type name collision from a different module" do
      ExtensionEvents.register(TerminalExtension)

      # Fake module that claims the same type name as TerminalExtension.
      # Deliberately omits @behaviour so register_all won't discover it.
      defmodule ConflictingTerminal do
        def type_names, do: [:terminal]
      end

      assert_raise RuntimeError, ~r/collision/i, fn ->
        ExtensionEvents.register(ConflictingTerminal)
      end
    end
  end

  # -- dispatch/3 -------------------------------------------------------------

  describe "dispatch/3" do
    test "routes to correct module by type name" do
      ExtensionEvents.register(TerminalExtension)
      ExtensionEvents.register(ChartExtension)

      assert {:ok, {:terminal_focus, "t"}} =
               ExtensionEvents.dispatch(:click, el("t", "terminal"), [])

      assert {:ok, {:chart_click, "c", "default"}} =
               ExtensionEvents.dispatch(:click, el("c", "bar_chart"), [])
    end

    test "passes args through to sim_events" do
      ExtensionEvents.register(TerminalExtension)

      assert {:ok, {:terminal_input, "t", "hello"}} =
               ExtensionEvents.dispatch(:input, el("t", "terminal"), ["hello"])
    end

    test "returns :not_handled for unregistered type" do
      assert :not_handled = ExtensionEvents.dispatch(:click, el("x", "unknown_widget"), [])
    end

    test "returns :not_handled when extension does not implement sim_events/3" do
      ExtensionEvents.register(MinimalExtension)

      assert :not_handled =
               ExtensionEvents.dispatch(:click, el("m", "minimal_widget"), [])
    end

    test "returns :not_handled when extension returns :not_handled for verb" do
      ExtensionEvents.register(TerminalExtension)

      assert :not_handled =
               ExtensionEvents.dispatch(:slide, el("t", "terminal"), [42])
    end

    test "passes props through element" do
      ExtensionEvents.register(ChartExtension)

      assert {:ok, {:chart_click, "c", "revenue"}} =
               ExtensionEvents.dispatch(
                 :click,
                 el("c", "bar_chart", %{"series" => "revenue"}),
                 []
               )
    end
  end

  # -- clear/0 ----------------------------------------------------------------

  describe "clear/0" do
    test "removes all registrations" do
      ExtensionEvents.register(TerminalExtension)
      ExtensionEvents.register(ChartExtension)

      assert {:ok, _} = ExtensionEvents.dispatch(:click, el("t", "terminal"), [])

      ExtensionEvents.clear()

      assert :not_handled = ExtensionEvents.dispatch(:click, el("t", "terminal"), [])
      assert :not_handled = ExtensionEvents.dispatch(:click, el("c", "bar_chart"), [])
    end
  end

  # -- register_all/0 ---------------------------------------------------------

  describe "register_all/0" do
    test "discovers and registers loaded extensions" do
      # Our test modules above implement Julep.Extension, so register_all
      # should pick them up.
      ExtensionEvents.register_all()

      assert {:ok, {:terminal_focus, "t"}} =
               ExtensionEvents.dispatch(:click, el("t", "terminal"), [])
    end
  end

  # -- EventMap integration ---------------------------------------------------

  describe "EventMap with extension fallback" do
    setup do
      ExtensionEvents.register(TerminalExtension)
      :ok
    end

    test "click/1 falls through to extension" do
      assert {:ok, {:terminal_focus, "t"}} = EventMap.click(el("t", "terminal"))
    end

    test "input/2 falls through to extension" do
      assert {:ok, {:terminal_input, "t", "hi"}} =
               EventMap.input(el("t", "terminal"), "hi")
    end

    test "submit/1 returns error for unhandled extension verb" do
      assert {:error, msg} = EventMap.submit(el("t", "terminal"))
      assert msg =~ "cannot submit"
    end

    test "toggle/1 returns error for unhandled extension verb" do
      assert {:error, msg} = EventMap.toggle(el("t", "terminal"))
      assert msg =~ "cannot toggle"
    end

    test "select/2 returns error for unhandled extension verb" do
      assert {:error, msg} = EventMap.select(el("t", "terminal"), "v")
      assert msg =~ "cannot select"
    end

    test "slide/2 returns error for unhandled extension verb" do
      assert {:error, msg} = EventMap.slide(el("t", "terminal"), 5)
      assert msg =~ "cannot slide"
    end

    test "built-in widgets still work normally" do
      assert {:ok, %Widget{type: :click, id: "btn"}} = EventMap.click(el("btn", "button"))

      assert {:ok, %Widget{type: :input, id: "ti", value: "x"}} =
               EventMap.input(el("ti", "text_input"), "x")
    end

    test "helpful error messages preserved for mismatched verbs" do
      assert {:error, msg} = EventMap.click(el("cb", "checkbox"))
      assert msg =~ "use toggle/1 instead"

      assert {:error, msg} = EventMap.toggle(el("btn", "button"))
      assert msg =~ "use click/1 instead"
    end
  end
end
