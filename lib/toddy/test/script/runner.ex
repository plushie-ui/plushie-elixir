defmodule Toddy.Test.Script.Runner do
  @moduledoc """
  Executes parsed `.toddy` scripts.

  Creates a `Toddy.Test.Session`, runs each instruction sequentially,
  and collects results.
  """

  alias Toddy.Test.{Screenshot, Script, Session, TreeHash}

  @backend_map %{
    pooled_mock: Toddy.Test.Backend.Pooled,
    pooled_headless: Toddy.Test.Backend.Pooled,
    headless: Toddy.Test.Backend.Headless,
    windowed: Toddy.Test.Backend.Windowed
  }

  @doc """
  Runs a parsed script.

  Returns `:ok` on success or `{:error, failures}` where failures is a list
  of `{instruction, reason}` tuples.
  """
  @spec run(script :: Script.t(), opts :: keyword()) ::
          :ok | {:error, [{Script.instruction(), String.t()}]}
  def run(%{header: header, instructions: instructions}, opts \\ []) do
    replay? = Keyword.get(opts, :replay, false)
    backend_mod = Map.get(@backend_map, header.backend, Toddy.Test.Backend.Pooled)
    session = Session.start(header.app, backend: backend_mod)

    try do
      failures =
        instructions
        |> Enum.with_index(1)
        |> Enum.reduce([], fn {instruction, line_num}, failures ->
          case execute(session, instruction, replay?) do
            :ok -> failures
            {:error, reason} -> [{instruction, "line #{line_num}: #{reason}"} | failures]
          end
        end)

      if failures == [] do
        :ok
      else
        {:error, Enum.reverse(failures)}
      end
    after
      Session.stop(session)
    end
  end

  defp execute(session, {:click, selector}, _replay?) do
    Session.click(session, selector)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:type_text, selector, text}, _replay?) do
    Session.type_text(session, selector, text)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:type_key, key}, _replay?) do
    Session.type_key(session, key)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:press, key}, _replay?) do
    Session.press(session, key)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:release, key}, _replay?) do
    Session.release(session, key)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(_session, {:move, _selector}, _replay?) do
    # No-op: moving cursor to a widget by selector requires widget bounds
    # from layout, which only the renderer knows.
    :ok
  end

  defp execute(session, {:move_to, x, y}, _replay?) do
    Session.move_to(session, x, y)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:assert_model, expression}, _replay?) do
    # Basic string-match assertion against the inspected model.
    # assert_model checks that the expression string appears somewhere in the
    # inspect output of the current model. For exact equality, use `==`.
    model_str = session |> Session.model() |> inspect()

    if String.contains?(model_str, expression) do
      :ok
    else
      {:error, "assert_model failed: #{inspect(expression)} not found in model: #{model_str}"}
    end
  end

  defp execute(session, {:expect, text}, _replay?) do
    tree = Session.tree(session)

    if tree_contains_text?(tree, text) do
      :ok
    else
      {:error, "expected to find text #{inspect(text)} in tree"}
    end
  end

  defp execute(session, {:tree_hash, name}, _replay?) do
    snap = Session.tree_hash(session, name)
    golden_dir = Path.join(["test", "snapshots"])
    TreeHash.assert_match(snap, golden_dir)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:screenshot, name}, _replay?) do
    screenshot = Session.screenshot(session, name)
    golden_dir = Path.join(["test", "screenshots"])
    Screenshot.assert_match(screenshot, golden_dir)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:assert_text, selector, expected}, _replay?) do
    case Session.find(session, selector) do
      nil ->
        {:error, "element #{inspect(selector)} not found"}

      element ->
        actual = Toddy.Test.Element.text(element)

        if actual == expected do
          :ok
        else
          {:error,
           "expected text #{inspect(expected)} for #{inspect(selector)}, got #{inspect(actual)}"}
        end
    end
  end

  defp execute(_session, {:wait, ms}, replay?) do
    if replay?, do: Process.sleep(ms)
    :ok
  end

  # Recursively checks if any node in the tree contains the given text.
  defp tree_contains_text?(nil, _text), do: false

  defp tree_contains_text?(%{} = node, text) do
    props = node[:props] || node["props"] || %{}

    values = [
      props[:content] || props["content"],
      props[:label] || props["label"],
      props[:value] || props["value"],
      props[:placeholder] || props["placeholder"]
    ]

    if Enum.any?(values, &(&1 == text)) do
      true
    else
      children = node[:children] || node["children"] || []
      Enum.any?(children, &tree_contains_text?(&1, text))
    end
  end
end
