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

  @doc "Finds an element by its accessibility role. Returns nil if not found."
  @spec find_by_role(role :: atom() | String.t()) :: Element.t() | nil
  def find_by_role(role) when is_atom(role), do: find_by_role(to_string(role))
  def find_by_role(role) when is_binary(role), do: Session.find(session(), {:role, role})

  @doc "Finds an element by its accessibility label. Returns nil if not found."
  @spec find_by_label(label :: String.t()) :: Element.t() | nil
  def find_by_label(label) when is_binary(label), do: Session.find(session(), {:label, label})

  @doc "Finds the currently focused element. Returns nil if none is focused."
  @spec find_focused() :: Element.t() | nil
  def find_focused, do: Session.find(session(), :focused)

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

  @doc "Captures a pixel screenshot with the given name. No-op on :mock."
  @spec screenshot(name :: String.t()) :: Screenshot.t()
  def screenshot(name), do: Session.screenshot(session(), name)

  @doc """
  Save a screenshot as a PNG file to `test/screenshots/{name}.png`.

  Takes a screenshot, saves it, and returns the screenshot struct.
  Creates the `test/screenshots/` directory if it doesn't exist.
  No-op on backends that don't support pixel capture.
  """
  @spec save_screenshot(name :: String.t()) :: Screenshot.t()
  def save_screenshot(name) do
    s = screenshot(name)
    dir = Path.join("test", "screenshots")
    File.mkdir_p!(dir)
    Screenshot.save_png(s, Path.join(dir, "#{name}.png"))
    s
  end

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
  Asserts that a widget has the expected accessibility attributes.

  Finds the widget by selector and checks that its `a11y` prop map
  contains all the expected key-value pairs.

      assert_a11y("#heading", %{"role" => "heading", "level" => 1})
  """
  defmacro assert_a11y(selector, expected) do
    quote do
      element = Julep.Test.Helpers.find!(unquote(selector))
      raw_a11y = Julep.Test.Element.a11y(element)

      if is_nil(raw_a11y) do
        raise ExUnit.AssertionError,
          message:
            "Expected a11y props on element #{inspect(unquote(selector))}, but no a11y prop was set"
      end

      actual_a11y = raw_a11y

      for {key, expected_value} <- unquote(expected) do
        actual_value = Map.get(actual_a11y, key)

        unless actual_value == expected_value do
          raise ExUnit.AssertionError,
            message: """
            Expected a11y #{inspect(key)} to be #{inspect(expected_value)} \
            for #{inspect(unquote(selector))}, got #{inspect(actual_value)}

            Full a11y: #{inspect(actual_a11y)}
            """
        end
      end

      :ok
    end
  end

  @doc """
  Asserts that a widget has the expected accessibility role.

  Checks the inferred role (from widget type + any a11y override).

      assert_role("#save-button", "button")
      assert_role("#heading", "heading")
  """
  defmacro assert_role(selector, expected_role) do
    quote do
      element = Julep.Test.Helpers.find!(unquote(selector))
      actual_role = Julep.Test.Element.inferred_role(element)

      unless actual_role == unquote(expected_role) do
        raise ExUnit.AssertionError,
          message: """
          Expected role #{inspect(unquote(expected_role))} \
          for #{inspect(unquote(selector))}, got #{inspect(actual_role)}
          """
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
  :mock backend (empty hash is silently accepted).
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

  @doc "Presses a key (key down). Key string may include modifiers, e.g. `\"ctrl+s\"`."
  @spec press(key :: String.t()) :: :ok
  def press(key), do: Session.press(session(), key)

  @doc "Releases a key (key up). Key string may include modifiers, e.g. `\"ctrl+s\"`."
  @spec release(key :: String.t()) :: :ok
  def release(key), do: Session.release(session(), key)

  @doc "Moves the cursor to the given coordinates."
  @spec move_to(x :: number(), y :: number()) :: :ok
  def move_to(x, y), do: Session.move_to(session(), x, y)

  @doc "Types a key (press + release). Key string may include modifiers, e.g. `\"enter\"`."
  @spec type_key(key :: String.t()) :: :ok
  def type_key(key), do: Session.type_key(session(), key)

  @doc "Resets the session to initial state."
  @spec reset() :: :ok
  def reset, do: Session.reset(session())

  @doc """
  Creates and registers a new test session for `app`.

  Resolves the backend from `JULEP_TEST_BACKEND` env var, application
  config, or defaults to `:mock`. Stores the session in the process
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
