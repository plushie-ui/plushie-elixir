defmodule Plushie.Test.Session do
  @moduledoc """
  A test session wrapping a backend module and its process.

  Created by `Plushie.Test.Case` setup or `Plushie.Test.Helpers.start/1`.
  All interaction functions delegate to the backend.
  """

  alias Plushie.Test.Backend
  alias Plushie.Test.Element
  alias Plushie.Test.Screenshot
  alias Plushie.Test.TreeHash

  @type t :: %__MODULE__{
          backend: module(),
          pid: pid()
        }

  defstruct [:backend, :pid]

  @doc "Creates a new session by starting the given backend."
  @spec start(app :: module(), opts :: keyword()) :: t()
  def start(app, opts \\ []) do
    backend = Keyword.get(opts, :backend, Plushie.Test.Backend.MockRenderer)
    {:ok, pid} = backend.start(app, opts)
    %__MODULE__{backend: backend, pid: pid}
  end

  @doc "Stops the session."
  @spec stop(session :: t()) :: :ok
  def stop(%__MODULE__{backend: backend, pid: pid}), do: backend.stop(pid)

  @doc "Finds an element by selector. Returns nil if not found."
  @spec find(session :: t(), selector :: Backend.selector()) :: Element.t() | nil
  def find(%__MODULE__{backend: b, pid: p}, selector), do: b.find(p, selector)

  @doc "Finds an element by selector. Raises if not found."
  @spec find!(session :: t(), selector :: Backend.selector()) :: Element.t()
  def find!(%__MODULE__{backend: b, pid: p}, selector), do: b.find!(p, selector)

  @doc "Clicks a widget."
  @spec click(session :: t(), selector :: Backend.selector()) :: :ok
  def click(%__MODULE__{backend: b, pid: p}, selector), do: b.click(p, selector)

  @doc "Types text into a widget."
  @spec type_text(session :: t(), selector :: Backend.selector(), text :: String.t()) :: :ok
  def type_text(%__MODULE__{backend: b, pid: p}, selector, text),
    do: b.type_text(p, selector, text)

  @doc "Submits a widget (e.g., text_input on enter)."
  @spec submit(session :: t(), selector :: Backend.selector()) :: :ok
  def submit(%__MODULE__{backend: b, pid: p}, selector), do: b.submit(p, selector)

  @doc "Toggles a widget (checkbox, toggler)."
  @spec toggle(session :: t(), selector :: Backend.selector()) :: :ok
  def toggle(%__MODULE__{backend: b, pid: p}, selector), do: b.toggle(p, selector)

  @doc "Selects a value from a widget (pick_list, combo_box, radio)."
  @spec select(session :: t(), selector :: Backend.selector(), value :: term()) :: :ok
  def select(%__MODULE__{backend: b, pid: p}, selector, value), do: b.select(p, selector, value)

  @doc "Slides a slider to a value."
  @spec slide(session :: t(), selector :: Backend.selector(), value :: number()) :: :ok
  def slide(%__MODULE__{backend: b, pid: p}, selector, value), do: b.slide(p, selector, value)

  @doc "Returns the current model."
  @spec model(session :: t()) :: term()
  def model(%__MODULE__{backend: b, pid: p}), do: b.model(p)

  @doc "Returns the current normalized tree."
  @spec tree(session :: t()) :: map()
  def tree(%__MODULE__{backend: b, pid: p}), do: b.tree(p)

  @doc "Captures a structural tree hash. Works on all backends."
  @spec tree_hash(session :: t(), name :: String.t()) :: TreeHash.t()
  def tree_hash(%__MODULE__{backend: b, pid: p}, name), do: b.tree_hash(p, name)

  @doc "Captures a pixel screenshot."
  @spec screenshot(session :: t(), name :: String.t()) :: Screenshot.t()
  def screenshot(%__MODULE__{backend: b, pid: p}, name), do: b.screenshot(p, name)

  @doc "Resets the session to initial state."
  @spec reset(session :: t()) :: :ok
  def reset(%__MODULE__{backend: b, pid: p}), do: b.reset(p)

  @doc "Waits for a tagged async task to complete."
  @spec await_async(session :: t(), tag :: atom(), timeout :: non_neg_integer()) :: :ok
  def await_async(%__MODULE__{backend: b, pid: p}, tag, timeout \\ 5000),
    do: b.await_async(p, tag, timeout)

  @doc "Presses a key (key down). Key string may include modifiers, e.g. `\"ctrl+s\"`."
  @spec press(session :: t(), key :: String.t()) :: :ok
  def press(%__MODULE__{backend: b, pid: p}, key), do: b.press(p, key)

  @doc "Releases a key (key up). Key string may include modifiers, e.g. `\"ctrl+s\"`."
  @spec release(session :: t(), key :: String.t()) :: :ok
  def release(%__MODULE__{backend: b, pid: p}, key), do: b.release(p, key)

  @doc "Moves the cursor to the given coordinates."
  @spec move_to(session :: t(), x :: number(), y :: number()) :: :ok
  def move_to(%__MODULE__{backend: b, pid: p}, x, y), do: b.move_to(p, x, y)

  @doc "Types a key (press + release). Key string may include modifiers, e.g. `\"enter\"`."
  @spec type_key(session :: t(), key :: String.t()) :: :ok
  def type_key(%__MODULE__{backend: b, pid: p}, key), do: b.type_key(p, key)
end
