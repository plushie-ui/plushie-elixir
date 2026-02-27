defmodule Julep.Test.Backend do
  @moduledoc """
  Behaviour for test backends.

  Three backends provide different fidelity levels:

  - `:sim` -- pure Elixir, no Rust. Fastest. Tests logic and tree structure.
  - `:headless` -- real Rust renderer with iced_test Simulator. Pixel snapshots.
  - `:full` -- real iced windows (Xvfb in CI). Effects, subscriptions, GPU rendering.

  All backends return the same types (`Element`, `Snapshot`, etc.) so tests
  can switch backends without changing assertions.
  """

  alias Julep.Test.Element
  alias Julep.Test.Snapshot

  @type selector :: String.t() | {:point, number(), number()}

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
  @callback snapshot(session :: pid(), name :: String.t()) :: Snapshot.t()
  @callback reset(session :: pid()) :: :ok
  @callback await_async(session :: pid(), tag :: atom(), timeout :: non_neg_integer()) :: :ok
end
