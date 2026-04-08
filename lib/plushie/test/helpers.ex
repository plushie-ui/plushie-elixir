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

  alias Plushie.Automation.Element
  alias Plushie.Test.{Screenshot, Session, TreeHash}

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

  @doc """
  Clicks a widget identified by selector.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec click(selector :: Session.selector(), opts :: keyword()) :: :ok
  def click(selector, opts \\ []), do: Session.click(session(), selector, opts)

  @doc """
  Types text into a widget identified by selector.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec type_text(selector :: Session.selector(), text :: String.t(), opts :: keyword()) :: :ok
  def type_text(selector, text, opts \\ []),
    do: Session.type_text(session(), selector, text, opts)

  @doc """
  Submits a text input (simulates pressing enter).

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec submit(selector :: Session.selector(), opts :: keyword()) :: :ok
  def submit(selector, opts \\ []), do: Session.submit(session(), selector, opts)

  @doc """
  Toggles a checkbox or toggler.

  Without a value, reads the current state and negates it. With an
  explicit boolean, sets the widget directly without reading state.

      toggle("#dark_mode")          # flip current state
      toggle("#agree_check", true)  # check
      toggle("#agree_check", false) # uncheck

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec toggle(selector :: Session.selector(), value :: boolean() | nil, opts :: keyword()) :: :ok
  def toggle(selector, value \\ nil, opts \\ []),
    do: Session.toggle(session(), selector, value, opts)

  @doc """
  Selects a value from a pick_list, combo_box, or radio group.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec select(selector :: Session.selector(), value :: term(), opts :: keyword()) :: :ok
  def select(selector, value, opts \\ []), do: Session.select(session(), selector, value, opts)

  @doc """
  Slides a slider to the given value.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec slide(selector :: Session.selector(), value :: number(), opts :: keyword()) :: :ok
  def slide(selector, value, opts \\ []), do: Session.slide(session(), selector, value, opts)

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
      actual = Plushie.Automation.Element.text(element)

      unless actual == unquote(expected) do
        raise ExUnit.AssertionError,
          message: """
          Text mismatch for #{inspect(unquote(selector))}
          """,
          left: actual,
          right: unquote(expected)
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
      raw_a11y = Plushie.Automation.Element.a11y(element)

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
            a11y #{inspect(key)} mismatch for #{inspect(unquote(selector))}

            Full a11y: #{inspect(actual_a11y)}
            """,
            left: actual_value,
            right: expected_value
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
      actual_role = Plushie.Automation.Element.inferred_role(element)

      unless actual_role == unquote(expected_role) do
        raise ExUnit.AssertionError,
          message: """
          Role mismatch for #{inspect(unquote(selector))}
          """,
          left: actual_role,
          right: unquote(expected_role)
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
  Asserts that an existing tree hash matches the golden file.

  Use this when you already have a `%Plushie.Test.TreeHash{}` and want the
  imported helper form instead of calling `Plushie.Test.TreeHash.assert_match/2`
  directly.
  """
  @spec assert_tree_hash_match(tree_hash :: TreeHash.t(), golden_dir :: String.t()) :: :ok
  def assert_tree_hash_match(tree_hash, golden_dir) do
    TreeHash.assert_match(tree_hash, golden_dir)
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

  @doc """
  Asserts that an existing screenshot matches the golden file.

  Use this when you already have a `%Plushie.Automation.Screenshot{}` and want the
  imported helper form instead of calling `Plushie.Test.Screenshot.assert_match/2`
  directly.
  """
  @spec assert_screenshot_match(
          screenshot :: Screenshot.t(),
          golden_dir :: String.t()
        ) :: :ok
  def assert_screenshot_match(screenshot, golden_dir) do
    Screenshot.assert_match(screenshot, golden_dir)
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

  @doc """
  Scrolls a widget by the given deltas.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec scroll(
          selector :: Session.selector(),
          delta_x :: number(),
          delta_y :: number(),
          opts :: keyword()
        ) :: :ok
  def scroll(selector, delta_x \\ 0, delta_y \\ 0, opts \\ []),
    do: Session.scroll(session(), selector, delta_x, delta_y, opts)

  @doc """
  Pastes text into a widget.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec paste(selector :: Session.selector(), text :: String.t(), opts :: keyword()) :: :ok
  def paste(selector, text, opts \\ []), do: Session.paste(session(), selector, text, opts)

  @doc """
  Sorts a table column.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec sort(
          selector :: Session.selector(),
          column :: String.t(),
          direction :: String.t(),
          opts :: keyword()
        ) :: :ok
  def sort(selector, column, direction \\ "asc", opts \\ []),
    do: Session.sort(session(), selector, column, direction, opts)

  @doc """
  Presses on a canvas at the given coordinates.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec canvas_press(
          selector :: Session.selector(),
          x :: number(),
          y :: number(),
          button :: String.t(),
          opts :: keyword()
        ) :: :ok
  def canvas_press(selector, x, y, button \\ "left", opts \\ []),
    do: Session.canvas_press(session(), selector, x, y, button, opts)

  @doc """
  Releases on a canvas at the given coordinates.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec canvas_release(
          selector :: Session.selector(),
          x :: number(),
          y :: number(),
          button :: String.t(),
          opts :: keyword()
        ) :: :ok
  def canvas_release(selector, x, y, button \\ "left", opts \\ []),
    do: Session.canvas_release(session(), selector, x, y, button, opts)

  @doc """
  Moves on a canvas to the given coordinates.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec canvas_move(
          selector :: Session.selector(),
          x :: number(),
          y :: number(),
          opts :: keyword()
        ) :: :ok
  def canvas_move(selector, x, y, opts \\ []),
    do: Session.canvas_move(session(), selector, x, y, opts)

  @doc """
  Cycles focus in a pane grid.

  ## Options

  - `window:` -- target window ID for multi-window apps
  """
  @spec pane_focus_cycle(selector :: Session.selector(), opts :: keyword()) :: :ok
  def pane_focus_cycle(selector, opts \\ []),
    do: Session.pane_focus_cycle(session(), selector, opts)

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
  the given `kind`, without executing the real effect. The `kind`
  matches the effect function name as an atom (e.g. `:file_open`,
  `:clipboard_write`).
  """
  @spec register_effect_stub(kind :: Plushie.Effect.kind(), response :: term()) :: :ok
  def register_effect_stub(kind, response),
    do: Session.register_effect_stub(session(), kind, response)

  @doc """
  Removes a previously registered effect stub.
  """
  @spec unregister_effect_stub(kind :: Plushie.Effect.kind()) :: :ok
  def unregister_effect_stub(kind),
    do: Session.unregister_effect_stub(session(), kind)

  @doc """
  Asserts that no prop validation diagnostics have been emitted.

  Checks the telemetry-based diagnostic collector set up by
  `Plushie.Test.Case`. Raises `ExUnit.AssertionError` with the
  diagnostic details if any diagnostics were received.
  """
  @spec assert_no_diagnostics() :: :ok
  def assert_no_diagnostics do
    diagnostics = Plushie.Test.DiagnosticCollector.flush()

    if diagnostics != [] do
      details =
        Enum.map_join(diagnostics, "\n", fn d ->
          "  - [#{d[:level]}] #{d[:code]}: #{d[:message]}"
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
          message: "Model mismatch",
          left: actual,
          right: unquote(expected)
      end

      :ok
    end
  end

  @doc """
  Advances the renderer animation clock, driving both SDK-side
  animation frame events and renderer-side transitions.

  In mock mode this is a no-op for renderer-side transitions
  (they resolve instantly). In headless/windowed mode it advances
  the animation clock by the given timestamp.

  ## Example

      click("#toggle")
      advance_frame(150)   # 150ms into the animation
  """
  @spec advance_frame(timestamp :: non_neg_integer()) :: :ok
  def advance_frame(timestamp) when is_integer(timestamp) and timestamp >= 0 do
    Session.advance_frame(session(), timestamp)
  end

  @doc """
  Skips all active renderer-side transitions to completion.

  Advances the animation clock far enough to complete any
  reasonable animation (10 seconds). Useful in tests that
  trigger animations but only care about the final state.

  ## Example

      click("#toggle")
      skip_transitions()
      assert find!("#box").props[:opacity] == 0.0
  """
  @spec skip_transitions() :: :ok
  def skip_transitions do
    advance_frame(10_000)
  end
end
