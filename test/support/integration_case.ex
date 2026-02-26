defmodule Julep.IntegrationCase do
  @moduledoc """
  Test helper for integration-testing Julep apps.

  Use this module in your test files to get convenient helpers for
  starting apps, dispatching events, and asserting on tree state.

  ## Usage

      defmodule MyApp.IntegrationTest do
        use Julep.IntegrationCase, async: true

        test "counter increments" do
          {runtime, bridge} = start_app(MyApp.Counter)

          assert_tree(runtime, fn tree ->
            assert tree.type == "window"
          end)

          send_event(runtime, {:click, "increment"})

          model = get_model(runtime)
          assert model.count == 1
        end
      end
  """

  defmacro __using__(opts) do
    async = Keyword.get(opts, :async, true)

    quote do
      use ExUnit.Case, async: unquote(async)
      import Julep.IntegrationCase

      @moduletag :integration
    end
  end

  @doc """
  Starts a Julep app with a mock bridge. Returns {runtime_pid, bridge_name}.
  """
  def start_app(app_module, opts \\ []) do
    tag = System.unique_integer([:positive])
    bridge_name = :"integration_bridge_#{tag}"
    runtime_name = :"integration_runtime_#{tag}"

    {:ok, _bridge} = Julep.Test.MockBridge.start_link(name: bridge_name)

    runtime_opts =
      [app: app_module, bridge: bridge_name, name: runtime_name]
      |> Keyword.merge(opts)

    {:ok, runtime} = Julep.Runtime.start_link(runtime_opts)

    # Wait for initial render (handle_continue) to complete.
    :sys.get_state(runtime)

    {runtime, bridge_name}
  end

  @doc """
  Dispatches an event to the runtime and waits for processing.
  """
  def send_event(runtime, event) do
    Julep.Runtime.dispatch(runtime, event)
    :sys.get_state(runtime)
    :ok
  end

  @doc """
  Asserts on the current tree state. Calls the assertion function with the current tree.
  """
  def assert_tree(runtime, assertion_fn) when is_function(assertion_fn, 1) do
    state = :sys.get_state(runtime)
    assertion_fn.(state.tree)
  end

  @doc """
  Returns the current model from the runtime.
  """
  def get_model(runtime) do
    state = :sys.get_state(runtime)
    state.model
  end

  @doc """
  Returns the current tree from the runtime.
  """
  def get_tree(runtime) do
    state = :sys.get_state(runtime)
    state.tree
  end

  @doc """
  Returns snapshots sent to the bridge.
  """
  def get_snapshots(bridge) do
    Julep.Test.MockBridge.get_snapshots(bridge)
  end

  @doc """
  Returns patches sent to the bridge.
  """
  def get_patches(bridge) do
    Julep.Test.MockBridge.get_patches(bridge)
  end
end
