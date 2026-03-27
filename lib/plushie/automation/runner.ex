defmodule Plushie.Automation.Runner do
  @moduledoc """
  Executes parsed `.plushie` automation files.

  Starts a real Plushie app, attaches a `Plushie.Automation.Session`, runs each
  instruction sequentially, and collects results.

  The parsed automation header is forwarded to `app.init/1` under the `:script`
  option so apps can opt into script-specific setup if they want to.
  """

  alias Plushie.Automation.{Element, Screenshot, Session}
  alias Plushie.Automation.File, as: AutomationFile

  @doc """
  Runs a parsed automation file.

  Returns `:ok` on success or `{:error, failures}` where failures is a list
  of `{instruction, reason}` tuples.
  """
  @spec run(script :: AutomationFile.t(), opts :: keyword()) ::
          :ok | {:error, [{AutomationFile.instruction(), String.t()}]}
  def run(%{header: header, instructions: instructions}, opts \\ []) do
    replay? = Keyword.get(opts, :replay, false)
    instance_name = :"plushie_automation_#{System.unique_integer([:positive])}"

    {:ok, sup} =
      Plushie.start_link(header.app,
        name: instance_name,
        binary: Plushie.Binary.path!(),
        renderer_args: renderer_args(header.backend),
        app_opts: [script: header]
      )

    session = Session.attach(instance: instance_name)
    output_dir = Keyword.get(opts, :output_dir, Path.join(["tmp", "plushie_automation"]))

    try do
      failures =
        instructions
        |> Enum.with_index(1)
        |> Enum.reduce([], fn {instruction, line_num}, failures ->
          case execute(session, instruction, header, replay?, output_dir) do
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
      Plushie.stop(sup)
    end
  end

  defp execute(session, {:click, selector}, _header, _replay?, _output_dir) do
    Session.click(session, selector)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:toggle, selector, value}, _header, _replay?, _output_dir) do
    Session.toggle(session, selector, value)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:type_text, selector, text}, _header, _replay?, _output_dir) do
    Session.type_text(session, selector, text)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:type_key, key}, _header, _replay?, _output_dir) do
    Session.type_key(session, key)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:press, key}, _header, _replay?, _output_dir) do
    Session.press(session, key)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:release, key}, _header, _replay?, _output_dir) do
    Session.release(session, key)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(_session, {:move, _selector}, _header, _replay?, _output_dir) do
    # No-op: moving cursor to a widget by selector requires widget bounds
    # from layout, which only the renderer knows.
    :ok
  end

  defp execute(session, {:move_to, x, y}, _header, _replay?, _output_dir) do
    Session.move_to(session, x, y)
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:assert_model, expression}, _header, _replay?, _output_dir) do
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

  defp execute(session, {:expect, text}, _header, _replay?, _output_dir) do
    tree = Session.tree(session)

    if tree_contains_text?(tree, text) do
      :ok
    else
      {:error, "expected to find text #{inspect(text)} in tree"}
    end
  end

  defp execute(session, {:screenshot, name}, %{viewport: {width, height}}, _replay?, output_dir) do
    screenshot = Session.screenshot(session, name, width: width, height: height)
    dir = Path.join([output_dir, "screenshots"])
    File.mkdir_p!(dir)
    Screenshot.save_png(screenshot, Path.join(dir, "#{name}.png"))
    :ok
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp execute(session, {:assert_text, selector, expected}, _header, _replay?, _output_dir) do
    case Session.find(session, selector) do
      nil ->
        {:error, "element #{inspect(selector)} not found"}

      element ->
        actual = Element.text(element)

        if actual == expected do
          :ok
        else
          {:error,
           "expected text #{inspect(expected)} for #{inspect(selector)}, got #{inspect(actual)}"}
        end
    end
  end

  defp execute(_session, {:wait, ms}, _header, replay?, _output_dir) do
    if replay?, do: Process.sleep(ms)
    :ok
  end

  defp renderer_args(:mock), do: ["--mock"]
  defp renderer_args(:headless), do: ["--headless"]
  defp renderer_args(:windowed), do: []
  defp renderer_args(_), do: []

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
