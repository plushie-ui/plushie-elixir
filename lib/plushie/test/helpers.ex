defmodule Plushie.Test.Helpers do
  @moduledoc """
  Test helper functions imported by `Plushie.Test.Case`.

  These functions retrieve the current session from the process dictionary,
  so they can be called without passing a session explicitly.

  ## Usage

  These are automatically imported when using `Plushie.Test.Case`:

      use Plushie.Test.Case, app: MyApp

      test "example" do
        click("#my-button")
        assert model().count == 1
        assert_text("#label", "Count: 1")
      end

  They can also be used with an explicit session by calling through
  `Plushie.Test.Session` directly.
  """

  alias Plushie.Test.Element
  alias Plushie.Test.Screenshot
  alias Plushie.Test.Session
  alias Plushie.Test.TreeHash

  @doc "Returns the current test session from the process dictionary."
  @spec session() :: Session.t()
  def session do
    Process.get(:plushie_test_session) ||
      raise "No Plushie test session found. Are you using `use Plushie.Test.Case`?"
  end

  @doc "Finds an element by selector. Returns nil if not found."
  @spec find(selector :: Session.selector()) :: Element.t() | nil
  def find(selector), do: Session.find(session(), selector)

  @doc "Finds an element by selector. Raises if not found."
  @spec find!(selector :: Session.selector()) :: Element.t()
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
  @spec click(selector :: Session.selector()) :: :ok
  def click(selector), do: Session.click(session(), selector)

  @doc "Types text into a widget identified by selector."
  @spec type_text(selector :: Session.selector(), text :: String.t()) :: :ok
  def type_text(selector, text), do: Session.type_text(session(), selector, text)

  @doc "Submits a text input (simulates pressing enter)."
  @spec submit(selector :: Session.selector()) :: :ok
  def submit(selector), do: Session.submit(session(), selector)

  @doc """
  Toggles a checkbox or toggler.

  Without a value, reads the current state and negates it (upstream
  `.ice` script compatibility). With an explicit boolean, sets the
  widget directly without reading current state.

      toggle("#dark_mode")          # flip current state
      toggle("#agree_check", true)  # check
      toggle("#agree_check", false) # uncheck
  """
  @spec toggle(selector :: Session.selector(), value :: boolean() | nil) :: :ok
  def toggle(selector, value \\ nil), do: Session.toggle(session(), selector, value)

  @doc "Selects a value from a pick_list, combo_box, or radio group."
  @spec select(selector :: Session.selector(), value :: term()) :: :ok
  def select(selector, value), do: Session.select(session(), selector, value)

  @doc "Slides a slider to the given value."
  @spec slide(selector :: Session.selector(), value :: number()) :: :ok
  def slide(selector, value), do: Session.slide(session(), selector, value)

  @doc "Returns the current app model."
  @spec model() :: term()
  def model, do: Session.model(session())

  @doc "Returns the current normalized UI tree."
  @spec tree() :: map()
  def tree, do: Session.tree(session())

  @doc "Captures a structural tree hash with the given name."
  @spec tree_hash(name :: String.t()) :: TreeHash.t()
  def tree_hash(name), do: Session.tree_hash(session(), name)

  @doc "Captures a pixel screenshot with the given name."
  @spec screenshot(name :: String.t(), opts :: keyword()) :: Screenshot.t()
  def screenshot(name, opts \\ []), do: Session.screenshot(session(), name, opts)

  @doc """
  Save a screenshot as a PNG file to `test/screenshots/{name}.png`.

  Takes a screenshot, saves it, and returns the screenshot struct.
  Creates the `test/screenshots/` directory if it doesn't exist.
  No-op on backends that don't support pixel capture.
  """
  @spec save_screenshot(name :: String.t(), opts :: keyword()) :: Screenshot.t()
  def save_screenshot(name, opts \\ []) do
    s = screenshot(name, opts)
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
      element = Plushie.Test.Helpers.find!(unquote(selector))
      actual = Plushie.Test.Element.text(element)

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
      unless Plushie.Test.Helpers.find(unquote(selector)) do
        raise ExUnit.AssertionError,
          message: "Expected element #{inspect(unquote(selector))} to exist, but it was not found"
      end

      :ok
    end
  end

  @doc "Asserts that a widget does NOT exist in the tree."
  defmacro assert_not_exists(selector) do
    quote do
      if Plushie.Test.Helpers.find(unquote(selector)) do
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

      assert_a11y("#heading", %{role: :heading, level: 1})
  """
  defmacro assert_a11y(selector, expected) do
    quote do
      element = Plushie.Test.Helpers.find!(unquote(selector))
      raw_a11y = Plushie.Test.Element.a11y(element)

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
      element = Plushie.Test.Helpers.find!(unquote(selector))
      actual_role = Plushie.Test.Element.inferred_role(element)

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
  Captures a structural tree hash and asserts it matches the golden file.

  On first run, creates the golden file. On subsequent runs, compares hashes.
  Set `PLUSHIE_UPDATE_SNAPSHOTS=1` to force-update golden files.
  """
  @spec assert_tree_hash(name :: String.t()) :: :ok
  def assert_tree_hash(name) do
    snap = tree_hash(name)
    golden_dir = Path.join(["test", "snapshots"])
    TreeHash.assert_match(snap, golden_dir)
  end

  @doc """
  Captures a pixel screenshot and asserts it matches the golden file.

  On first run, creates the golden file. On subsequent runs, compares hashes.
  Set `PLUSHIE_UPDATE_SCREENSHOTS=1` to force-update golden files. No-op on
  backends that don't support pixel capture (empty hash is silently accepted).
  """
  @spec assert_screenshot(name :: String.t(), opts :: keyword()) :: :ok
  def assert_screenshot(name, opts \\ []) do
    snap = screenshot(name, opts)
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

  @doc "Scrolls a widget by the given deltas."
  @spec scroll(selector :: Session.selector(), delta_x :: number(), delta_y :: number()) :: :ok
  def scroll(selector, delta_x \\ 0, delta_y \\ 0),
    do: Session.scroll(session(), selector, delta_x, delta_y)

  @doc "Pastes text into a widget."
  @spec paste(selector :: Session.selector(), text :: String.t()) :: :ok
  def paste(selector, text), do: Session.paste(session(), selector, text)

  @doc "Sorts a table column."
  @spec sort(selector :: Session.selector(), column :: String.t(), direction :: String.t()) :: :ok
  def sort(selector, column, direction \\ "asc"),
    do: Session.sort(session(), selector, column, direction)

  @doc "Presses on a canvas at the given coordinates."
  @spec canvas_press(
          selector :: Session.selector(),
          x :: number(),
          y :: number(),
          button :: String.t()
        ) :: :ok
  def canvas_press(selector, x, y, button \\ "left"),
    do: Session.canvas_press(session(), selector, x, y, button)

  @doc "Releases on a canvas at the given coordinates."
  @spec canvas_release(
          selector :: Session.selector(),
          x :: number(),
          y :: number(),
          button :: String.t()
        ) :: :ok
  def canvas_release(selector, x, y, button \\ "left"),
    do: Session.canvas_release(session(), selector, x, y, button)

  @doc "Moves on a canvas to the given coordinates."
  @spec canvas_move(selector :: Session.selector(), x :: number(), y :: number()) :: :ok
  def canvas_move(selector, x, y), do: Session.canvas_move(session(), selector, x, y)

  @doc "Cycles focus in a pane grid."
  @spec pane_focus_cycle(selector :: Session.selector()) :: :ok
  def pane_focus_cycle(selector), do: Session.pane_focus_cycle(session(), selector)

  @doc "Resets the session to initial state."
  @spec reset() :: :ok
  def reset, do: Session.reset(session())

  @doc """
  Creates and registers a new test session for `app`.

  Resolves the backend from `PLUSHIE_TEST_BACKEND` env var, application
  config, or defaults to `:mock`. Stores the session in the process
  dictionary so all helper functions work without explicit session threading.

  Call this in a test or setup block when not using `Plushie.Test.Case`.
  """
  @spec start(app :: module()) :: Session.t()
  def start(app) do
    session = Session.start(app)
    Process.put(:plushie_test_session, session)
    session
  end

  @doc """
  Registers an effect stub with the renderer for the current session.

  The renderer will return `response` immediately for any effect of
  the given `kind`, without executing the real effect.
  """
  @spec register_effect_stub(kind :: String.t(), response :: term()) :: :ok
  def register_effect_stub(kind, response),
    do: Session.register_effect_stub(session(), kind, response)

  @doc """
  Removes a previously registered effect stub.
  """
  @spec unregister_effect_stub(kind :: String.t()) :: :ok
  def unregister_effect_stub(kind),
    do: Session.unregister_effect_stub(session(), kind)

  @doc """
  Asserts that no prop validation diagnostics have been emitted.

  Returns `:ok` if no diagnostics are pending. Raises
  `ExUnit.AssertionError` with the diagnostic details otherwise.
  Clears the diagnostic list after checking.
  """
  @spec assert_no_diagnostics() :: :ok
  def assert_no_diagnostics do
    diagnostics = Session.get_diagnostics(session())

    if diagnostics != [] do
      details =
        Enum.map_join(diagnostics, "\n", fn d ->
          "  - #{inspect(d.data)}"
        end)

      raise ExUnit.AssertionError,
        message: "Expected no prop validation diagnostics, but found:\n#{details}"
    end

    :ok
  end

  @doc """
  Asserts that the current model equals `expected`.

  Uses strict equality (`==`). Raises `ExUnit.AssertionError` with a diff-
  friendly message on mismatch.
  """
  defmacro assert_model(expected) do
    quote do
      actual = Plushie.Test.Helpers.model()

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
