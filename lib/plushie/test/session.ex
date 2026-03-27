defmodule Plushie.Test.Session do
  @moduledoc """
  A test session wrapping a running Plushie app.

  Created by `Plushie.Test.Case` setup. All interaction functions
  delegate to `Plushie.Test.Backend.Runtime`.
  """

  alias Plushie.Automation.Element
  alias Plushie.Test.{Backend.Runtime, Screenshot, TreeHash}

  @typedoc """
  Test selector.

  String selectors follow these rules:
  - `"#save"` matches a unique local widget ID
  - `"#form/save"` matches an exact scoped ID
  - bare strings like `"Save"` match visible text
  """
  @type selector :: Plushie.Automation.Session.selector()

  @type t :: %__MODULE__{pid: pid()}
  defstruct [:pid]

  @doc "Starts a new test session."
  @spec start(app :: module(), opts :: keyword()) :: t()
  def start(app, opts \\ []) do
    {:ok, pid} = Runtime.start(app, opts)
    %__MODULE__{pid: pid}
  end

  @spec stop(session :: t()) :: :ok
  def stop(%__MODULE__{pid: p}), do: Runtime.stop(p)

  @spec find(session :: t(), selector :: selector()) :: Element.t() | nil
  def find(%__MODULE__{pid: p}, selector), do: Runtime.find(p, selector)

  @spec find!(session :: t(), selector :: selector()) :: Element.t()
  def find!(%__MODULE__{pid: p}, selector), do: Runtime.find!(p, selector)

  @spec click(session :: t(), selector :: selector(), opts :: keyword()) :: :ok
  def click(%__MODULE__{pid: p}, selector, opts \\ []), do: Runtime.click(p, selector, opts)

  @spec type_text(session :: t(), selector :: selector(), text :: String.t(), opts :: keyword()) ::
          :ok
  def type_text(%__MODULE__{pid: p}, selector, text, opts \\ []),
    do: Runtime.type_text(p, selector, text, opts)

  @spec submit(session :: t(), selector :: selector(), opts :: keyword()) :: :ok
  def submit(%__MODULE__{pid: p}, selector, opts \\ []), do: Runtime.submit(p, selector, opts)

  @spec toggle(
          session :: t(),
          selector :: selector(),
          value :: boolean() | nil,
          opts :: keyword()
        ) :: :ok
  def toggle(%__MODULE__{pid: p}, selector, value \\ nil, opts \\ []),
    do: Runtime.toggle(p, selector, value, opts)

  @spec select(session :: t(), selector :: selector(), value :: term(), opts :: keyword()) :: :ok
  def select(%__MODULE__{pid: p}, selector, value, opts \\ []),
    do: Runtime.select(p, selector, value, opts)

  @spec slide(session :: t(), selector :: selector(), value :: number(), opts :: keyword()) :: :ok
  def slide(%__MODULE__{pid: p}, selector, value, opts \\ []),
    do: Runtime.slide(p, selector, value, opts)

  @spec model(session :: t()) :: term()
  def model(%__MODULE__{pid: p}), do: Runtime.model(p)

  @spec tree(session :: t()) :: map()
  def tree(%__MODULE__{pid: p}), do: Runtime.tree(p)

  @spec tree_hash(session :: t(), name :: String.t()) :: TreeHash.t()
  def tree_hash(%__MODULE__{pid: p}, name), do: Runtime.tree_hash(p, name)

  @spec screenshot(session :: t(), name :: String.t(), opts :: keyword()) :: Screenshot.t()
  def screenshot(%__MODULE__{pid: p}, name, opts \\ []), do: Runtime.screenshot(p, name, opts)

  @spec reset(session :: t()) :: :ok
  def reset(%__MODULE__{pid: p}), do: Runtime.reset(p)

  @spec await_async(session :: t(), tag :: atom(), timeout :: non_neg_integer()) :: :ok
  def await_async(%__MODULE__{pid: p}, tag, timeout \\ 5000),
    do: Runtime.await_async(p, tag, timeout)

  @spec press(session :: t(), key :: String.t()) :: :ok
  def press(%__MODULE__{pid: p}, key), do: Runtime.press(p, key)

  @spec release(session :: t(), key :: String.t()) :: :ok
  def release(%__MODULE__{pid: p}, key), do: Runtime.release(p, key)

  @spec move_to(session :: t(), x :: number(), y :: number()) :: :ok
  def move_to(%__MODULE__{pid: p}, x, y), do: Runtime.move_to(p, x, y)

  @spec type_key(session :: t(), key :: String.t()) :: :ok
  def type_key(%__MODULE__{pid: p}, key), do: Runtime.type_key(p, key)

  @spec scroll(
          session :: t(),
          selector :: selector(),
          delta_x :: number(),
          delta_y :: number(),
          opts :: keyword()
        ) :: :ok
  def scroll(%__MODULE__{pid: p}, selector, delta_x \\ 0, delta_y \\ 0, opts \\ []),
    do: Runtime.scroll(p, selector, delta_x, delta_y, opts)

  @spec paste(session :: t(), selector :: selector(), text :: String.t(), opts :: keyword()) ::
          :ok
  def paste(%__MODULE__{pid: p}, selector, text, opts \\ []),
    do: Runtime.paste(p, selector, text, opts)

  @spec sort(
          session :: t(),
          selector :: selector(),
          column :: String.t(),
          direction :: String.t(),
          opts :: keyword()
        ) :: :ok
  def sort(%__MODULE__{pid: p}, selector, column, direction \\ "asc", opts \\ []),
    do: Runtime.sort(p, selector, column, direction, opts)

  @spec canvas_press(
          session :: t(),
          selector :: selector(),
          x :: number(),
          y :: number(),
          button :: String.t(),
          opts :: keyword()
        ) :: :ok
  def canvas_press(%__MODULE__{pid: p}, selector, x, y, button \\ "left", opts \\ []),
    do: Runtime.canvas_press(p, selector, x, y, button, opts)

  @spec canvas_release(
          session :: t(),
          selector :: selector(),
          x :: number(),
          y :: number(),
          button :: String.t(),
          opts :: keyword()
        ) :: :ok
  def canvas_release(%__MODULE__{pid: p}, selector, x, y, button \\ "left", opts \\ []),
    do: Runtime.canvas_release(p, selector, x, y, button, opts)

  @spec canvas_move(
          session :: t(),
          selector :: selector(),
          x :: number(),
          y :: number(),
          opts :: keyword()
        ) :: :ok
  def canvas_move(%__MODULE__{pid: p}, selector, x, y, opts \\ []),
    do: Runtime.canvas_move(p, selector, x, y, opts)

  @spec pane_focus_cycle(session :: t(), selector :: selector(), opts :: keyword()) :: :ok
  def pane_focus_cycle(%__MODULE__{pid: p}, selector, opts \\ []),
    do: Runtime.pane_focus_cycle(p, selector, opts)

  @spec register_effect_stub(session :: t(), kind :: String.t(), response :: term()) :: :ok
  def register_effect_stub(%__MODULE__{pid: p}, kind, response),
    do: Runtime.register_effect_stub(p, kind, response)

  @spec unregister_effect_stub(session :: t(), kind :: String.t()) :: :ok
  def unregister_effect_stub(%__MODULE__{pid: p}, kind),
    do: Runtime.unregister_effect_stub(p, kind)

  @spec get_diagnostics(session :: t()) :: [Plushie.Event.SystemEvent.t()]
  def get_diagnostics(%__MODULE__{pid: p}), do: Runtime.get_diagnostics(p)
end
