defmodule Plushie.Test.Backend do
  @moduledoc """
  Behaviour for test backends.

  Three backends provide different fidelity levels:

  - `:mock` -- runs the plushie binary in `--mock` mode (lightweight rendering, no display). Sessions are pooled for performance.
  - `:headless` -- real Rust renderer with iced_test Simulator. Structural snapshots.
  - `:windowed` -- real iced windows (Xvfb in CI). Effects, subscriptions, GPU rendering.

  All backends return the same types (`Element`, `TreeHash`, `Screenshot`,
  etc.) so tests can switch backends without changing assertions.
  """

  alias Plushie.Test.Element
  alias Plushie.Test.Screenshot
  alias Plushie.Test.TreeHash

  @type selector :: String.t() | {:role, String.t()} | {:label, String.t()} | :focused

  @callback start(app :: module(), opts :: keyword()) :: {:ok, pid()}
  @callback stop(session :: pid()) :: :ok
  @callback find(session :: pid(), selector :: selector()) :: Element.t() | nil
  @callback find!(session :: pid(), selector :: selector()) :: Element.t()
  @callback click(session :: pid(), selector :: selector()) :: :ok
  @callback type_text(session :: pid(), selector :: selector(), text :: String.t()) :: :ok
  @callback submit(session :: pid(), selector :: selector()) :: :ok
  @callback toggle(session :: pid(), selector :: selector()) :: :ok
  @callback select(session :: pid(), selector :: selector(), value :: term()) :: :ok
  @callback slide(session :: pid(), selector :: selector(), value :: number()) :: :ok
  @callback model(session :: pid()) :: term()
  @callback tree(session :: pid()) :: map()
  @callback tree_hash(session :: pid(), name :: String.t()) :: TreeHash.t()
  @callback screenshot(session :: pid(), name :: String.t()) :: Screenshot.t()
  @callback reset(session :: pid()) :: :ok
  @callback await_async(session :: pid(), tag :: atom(), timeout :: non_neg_integer()) :: :ok
  @callback press(session :: pid(), key :: String.t()) :: :ok
  @callback release(session :: pid(), key :: String.t()) :: :ok
  @callback move_to(session :: pid(), x :: number(), y :: number()) :: :ok
  @callback type_key(session :: pid(), key :: String.t()) :: :ok
  @callback scroll(
              session :: pid(),
              selector :: selector(),
              delta_x :: number(),
              delta_y :: number()
            ) :: :ok
  @callback paste(session :: pid(), selector :: selector(), text :: String.t()) :: :ok
  @callback sort(
              session :: pid(),
              selector :: selector(),
              column :: String.t(),
              direction :: String.t()
            ) :: :ok
  @callback canvas_press(
              session :: pid(),
              selector :: selector(),
              x :: number(),
              y :: number(),
              button :: String.t()
            ) :: :ok
  @callback canvas_release(
              session :: pid(),
              selector :: selector(),
              x :: number(),
              y :: number(),
              button :: String.t()
            ) :: :ok
  @callback canvas_move(session :: pid(), selector :: selector(), x :: number(), y :: number()) ::
              :ok
  @callback pane_focus_cycle(session :: pid(), selector :: selector()) :: :ok
end
