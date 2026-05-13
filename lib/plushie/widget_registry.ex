defmodule Plushie.WidgetRegistry do
  @moduledoc """
  Discovers widgets via `Plushie.Tree.Node` protocol consolidation.

  All modules implementing the `Plushie.Tree.Node` protocol are widgets.
  Native widgets (those with Rust crates) additionally export `native_crate/0`.

  Results are cached in `:persistent_term` after first access. Call
  `invalidate/0` to clear the cache (used by the dev server after
  protocol reconsolidation).
  """

  @doc "Returns all modules implementing the Plushie.Tree.Node protocol."
  @spec all_widgets() :: [module()]
  def all_widgets do
    cached(:all, &protocol_impls/0)
  end

  @doc "Returns widget modules that have a native Rust crate."
  @spec native_widgets() :: [module()]
  def native_widgets do
    Enum.filter(all_widgets(), &function_exported?(&1, :native_crate, 0))
  end

  @doc "Clears the cached widget list. Called by DevServer after reconsolidation."
  @spec invalidate() :: :ok
  def invalidate do
    :persistent_term.erase({__MODULE__, :all})
    :ok
  rescue
    # Key might not exist yet.
    ArgumentError -> :ok
  end

  # The :not_consolidated branch is needed for test mode where
  # consolidate_protocols is disabled. Dialyzer only sees the dev
  # build where the protocol is always consolidated.
  defp protocol_impls do
    case apply(Plushie.Tree.Node, :__protocol__, [:impls]) do
      {:consolidated, impls} -> impls
      :not_consolidated -> Protocol.extract_impls(Plushie.Tree.Node, :code.get_path())
    end
  end

  defp cached(key, fun) do
    case :persistent_term.get({__MODULE__, key}, :unset) do
      :unset ->
        result = fun.()
        :persistent_term.put({__MODULE__, key}, result)
        result

      result ->
        result
    end
  end
end
