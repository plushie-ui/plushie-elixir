defmodule Julep.Test.Helpers do
  @moduledoc """
  Test helper functions imported by `Julep.Test.Case`.

  These functions retrieve the current session from the process dictionary,
  so they can be called without passing a session explicitly.

  ## Usage

  These are automatically imported when using `Julep.Test.Case`:

      use Julep.Test.Case, app: MyApp

      test "example" do
        click("#my-button")
        assert model().count == 1
        assert_text("#label", "Count: 1")
      end

  They can also be used with an explicit session by calling through
  `Julep.Test.Session` directly.
  """

  alias Julep.Test.Backend
  alias Julep.Test.Element
  alias Julep.Test.Screenshot
  alias Julep.Test.Session
  alias Julep.Test.Snapshot

  @doc "Returns the current test session from the process dictionary."
  @spec session() :: Session.t()
  def session do
    Process.get(:julep_test_session) ||
      raise "No Julep test session found. Are you using `use Julep.Test.Case`?"
  end

  @doc "Finds an element by selector. Returns nil if not found."
  @spec find(selector :: Backend.selector()) :: Element.t() | nil
  def find(selector), do: Session.find(session(), selector)

  @doc "Finds an element by selector. Raises if not found."
  @spec find!(selector :: Backend.selector()) :: Element.t()
  def find!(selector), do: Session.find!(session(), selector)

  @doc "Clicks a widget identified by selector."
  @spec click(selector :: Backend.selector()) :: :ok
  def click(selector), do: Session.click(session(), selector)

  @doc "Types text into a widget identified by selector."
  @spec type_text(selector :: Backend.selector(), text :: String.t()) :: :ok
  def type_text(selector, text), do: Session.type_text(session(), selector, text)

  @doc "Submits a text input (simulates pressing enter)."
  @spec submit(selector :: Backend.selector()) :: :ok
  def submit(selector), do: Session.submit(session(), selector)

  @doc "Toggles a checkbox or toggler."
  @spec toggle(selector :: Backend.selector()) :: :ok
  def toggle(selector), do: Session.toggle(session(), selector)

  @doc "Selects a value from a pick_list, combo_box, or radio group."
  @spec select(selector :: Backend.selector(), value :: term()) :: :ok
  def select(selector, value), do: Session.select(session(), selector, value)

  @doc "Slides a slider to the given value."
  @spec slide(selector :: Backend.selector(), value :: number()) :: :ok
  def slide(selector, value), do: Session.slide(session(), selector, value)

  @doc "Returns the current app model."
  @spec model() :: term()
  def model, do: Session.model(session())

  @doc "Returns the current normalized UI tree."
  @spec tree() :: map()
  def tree, do: Session.tree(session())

  @doc "Captures a structural tree snapshot with the given name."
  @spec snapshot(name :: String.t()) :: Snapshot.t()
  def snapshot(name), do: Session.snapshot(session(), name)

  @doc "Captures a pixel screenshot with the given name. No-op on :sim and :headless."
  @spec screenshot(name :: String.t()) :: Screenshot.t()
  def screenshot(name), do: Session.screenshot(session(), name)

  @doc "Extracts text content from an element."
  @spec text(element :: Element.t()) :: String.t() | nil
  def text(%Element{} = element), do: Element.text(element)

  @doc """
  Asserts that a widget contains the expected text.

  Finds the widget by selector and compares its text content.
  """
  defmacro assert_text(selector, expected) do
    quote do
      element = Julep.Test.Helpers.find!(unquote(selector))
      actual = Julep.Test.Element.text(element)

      unless actual == unquote(expected) do
        raise ExUnit.AssertionError,
          message: """
          Expected text #{inspect(unquote(expected))} for #{inspect(unquote(selector))},
          got #{inspect(actual)}
          """
      end

      :ok
    end
  end

  @doc "Asserts that a widget exists in the tree."
  defmacro assert_exists(selector) do
    quote do
      unless Julep.Test.Helpers.find(unquote(selector)) do
        raise ExUnit.AssertionError,
          message: "Expected element #{inspect(unquote(selector))} to exist, but it was not found"
      end

      :ok
    end
  end

  @doc "Asserts that a widget does NOT exist in the tree."
  defmacro assert_not_exists(selector) do
    quote do
      if Julep.Test.Helpers.find(unquote(selector)) do
        raise ExUnit.AssertionError,
          message: "Expected element #{inspect(unquote(selector))} to NOT exist, but it was found"
      end

      :ok
    end
  end

  @doc """
  Captures a structural tree snapshot and asserts it matches the golden file.

  On first run, creates the golden file. On subsequent runs, compares hashes.
  Set `JULEP_UPDATE_SNAPSHOTS=1` to force-update golden files.
  """
  @spec assert_snapshot(name :: String.t()) :: :ok
  def assert_snapshot(name) do
    snap = snapshot(name)
    golden_dir = Path.join(["test", "snapshots"])
    Snapshot.assert_match(snap, golden_dir)
  end

  @doc """
  Captures a pixel screenshot and asserts it matches the golden file.

  On first run, creates the golden file. On subsequent runs, compares hashes.
  Set `JULEP_UPDATE_SCREENSHOTS=1` to force-update golden files. No-op on
  :sim and :headless backends (empty hash is silently accepted).
  """
  @spec assert_screenshot(name :: String.t()) :: :ok
  def assert_screenshot(name) do
    snap = screenshot(name)
    golden_dir = Path.join(["test", "screenshots"])
    Screenshot.assert_match(snap, golden_dir)
  end

  @doc "Waits for a tagged async task to complete."
  @spec await_async(tag :: atom(), timeout :: non_neg_integer()) :: :ok
  def await_async(tag, timeout \\ 5000), do: Session.await_async(session(), tag, timeout)

  @doc "Resets the session to initial state."
  @spec reset() :: :ok
  def reset, do: Session.reset(session())

  @doc """
  Creates and registers a new test session for `app`.

  Resolves the backend from `JULEP_TEST_BACKEND` env var, application
  config, or defaults to `:sim`. Stores the session in the process
  dictionary so all helper functions work without explicit session threading.

  Call this in a test or setup block when not using `Julep.Test.Case`.
  """
  @spec start(app :: module()) :: Session.t()
  def start(app) do
    backend_mod = Julep.Test.Case.resolve_backend()
    session = Session.start(app, backend: backend_mod)
    Process.put(:julep_test_session, session)
    session
  end

  @doc """
  Asserts that the current model equals `expected`.

  Uses strict equality (`==`). Raises `ExUnit.AssertionError` with a diff-
  friendly message on mismatch.
  """
  defmacro assert_model(expected) do
    quote do
      actual = Julep.Test.Helpers.model()

      unless actual == unquote(expected) do
        raise ExUnit.AssertionError,
          message: """
          Expected model:
            #{inspect(unquote(expected))}
          Got:
            #{inspect(actual)}
          """
      end

      :ok
    end
  end
end
