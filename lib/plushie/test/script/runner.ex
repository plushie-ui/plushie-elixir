defmodule Plushie.Test.Script.Runner do
  @moduledoc """
  Executes parsed `.plushie` scripts.

  Creates a `Plushie.Test.Session`, runs each instruction sequentially,
  and collects results.
  """

  alias Plushie.Test.{Screenshot, Script, Session, SessionPool, TreeHash}

  @backend_map %{
    mock: Plushie.Test.Backend.Runtime,
    headless: Plushie.Test.Backend.Runtime,
    windowed: Plushie.Test.Backend.Runtime
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
    backend_mod = Map.get(@backend_map, header.backend, Plushie.Test.Backend.Runtime)
    pool_name = :"plushie_script_pool_#{System.unique_integer([:positive])}"

    {:ok, pool_pid} =
      SessionPool.start_link(
        name: pool_name,
        renderer: Plushie.Binary.path!(),
        mode: header.backend,
        rust_log: "off"
      )

    session =
      Session.start(header.app, backend: backend_mod, pool: pool_name, mode: header.backend)

    try do
      failures =
        instructions
        |> Enum.with_index(1)
        |> Enum.reduce([], fn {instruction, line_num}, failures ->
          case execute(session, instruction, header, replay?) do
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
      GenServer.stop(pool_pid, :normal, 10_000)
    end
  end

  defp execute(session, {:click, selector}, _header, _replay?) do
    Session.click(session, selector)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:toggle, selector, value}, _header, _replay?) do
    Session.toggle(session, selector, value)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:type_text, selector, text}, _header, _replay?) do
    Session.type_text(session, selector, text)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:type_key, key}, _header, _replay?) do
    Session.type_key(session, key)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:press, key}, _header, _replay?) do
    Session.press(session, key)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:release, key}, _header, _replay?) do
    Session.release(session, key)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(_session, {:move, _selector}, _header, _replay?) do
    # No-op: moving cursor to a widget by selector requires widget bounds
    # from layout, which only the renderer knows.
    :ok
  end

  defp execute(session, {:move_to, x, y}, _header, _replay?) do
    Session.move_to(session, x, y)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:assert_model, expression}, _header, _replay?) do
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

  defp execute(session, {:expect, text}, _header, _replay?) do
    tree = Session.tree(session)

    if tree_contains_text?(tree, text) do
      :ok
    else
      {:error, "expected to find text #{inspect(text)} in tree"}
    end
  end

  defp execute(session, {:tree_hash, name}, _header, _replay?) do
    snap = Session.tree_hash(session, name)
    golden_dir = Path.join(["test", "snapshots"])
    TreeHash.assert_match(snap, golden_dir)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:screenshot, name}, %{viewport: {width, height}}, _replay?) do
    screenshot = Session.screenshot(session, name, width: width, height: height)
    golden_dir = Path.join(["test", "screenshots"])
    Screenshot.assert_match(screenshot, golden_dir)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:assert_text, selector, expected}, _header, _replay?) do
    case Session.find(session, selector) do
      nil ->
        {:error, "element #{inspect(selector)} not found"}

      element ->
        actual = Plushie.Test.Element.text(element)

        if actual == expected do
          :ok
        else
          {:error,
           "expected text #{inspect(expected)} for #{inspect(selector)}, got #{inspect(actual)}"}
        end
    end
  end

  defp execute(_session, {:wait, ms}, _header, replay?) do
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
