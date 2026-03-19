defmodule Julep.Test.Script do
  @moduledoc """
  Parser for `.julep` test scripts.

  The `.julep` format is a superset of iced's `.ice` test script format,
  adding Julep-specific instructions like `assert_text` and `assert_model`.

  ## Format

      app: MyApp.Counter
      viewport: 800x600
      theme: dark
      backend: mock
      -----
      click "#increment"
      expect "Count: 1"
      snapshot "counter-at-1"

  See `Julep.Test.Script.Runner` for execution.
  """

  @type header :: %{
          app: module(),
          viewport: {non_neg_integer(), non_neg_integer()},
          theme: String.t(),
          backend: atom()
        }

  @type instruction ::
          {:click, String.t()}
          | {:type_text, String.t(), String.t()}
          | {:type_key, String.t()}
          | {:press, String.t()}
          | {:release, String.t()}
          | {:move, String.t()}
          | {:move_to, non_neg_integer(), non_neg_integer()}
          | {:toggle, String.t()}
          | {:select, String.t(), String.t()}
          | {:slide, String.t(), number()}
          | {:expect, String.t()}
          | {:snapshot, String.t()}
          | {:screenshot, String.t()}
          | {:assert_text, String.t(), String.t()}
          | {:assert_model, String.t()}
          | {:wait, non_neg_integer()}

  @type t :: %{header: header(), instructions: [instruction()]}

  @doc "Parses a .julep script from a file path."
  @spec parse_file(path :: String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse_file(path) do
    case File.read(path) do
      {:ok, content} -> parse(content)
      {:error, reason} -> {:error, "failed to read #{path}: #{inspect(reason)}"}
    end
  end

  @doc "Parses a .julep script from a string."
  @spec parse(content :: String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(content) do
    case String.split(content, ~r/^-----\s*$/m, parts: 2) do
      [header_section, body_section] ->
        with {:ok, header} <- parse_header(header_section),
             {:ok, instructions} <- parse_instructions(body_section) do
          {:ok, %{header: header, instructions: instructions}}
        end

      [_no_separator] ->
        {:error, "missing ----- separator between header and instructions"}
    end
  end

  defp parse_header(text) do
    fields =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, ":", parts: 2) do
          [key, value] -> Map.put(acc, String.trim(key), String.trim(value))
          _ -> acc
        end
      end)

    case Map.fetch(fields, "app") do
      {:ok, app_str} ->
        app = Module.concat([app_str])
        viewport = parse_viewport(Map.get(fields, "viewport", "800x600"))
        theme = Map.get(fields, "theme", "dark")
        backend = parse_backend(Map.get(fields, "backend", "mock"))
        {:ok, %{app: app, viewport: viewport, theme: theme, backend: backend}}

      :error ->
        {:error, "header must include 'app:' field"}
    end
  end

  defp parse_viewport(str) do
    case String.split(str, "x") do
      [w, h] -> {String.to_integer(w), String.to_integer(h)}
      _ -> {800, 600}
    end
  end

  defp parse_backend("mock"), do: :mock
  defp parse_backend("headless"), do: :headless
  defp parse_backend("windowed"), do: :windowed
  defp parse_backend(_), do: :mock

  defp parse_instructions(text) do
    instructions =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      |> Enum.map(&parse_instruction/1)

    errors = for {:error, msg} <- instructions, do: msg

    if errors == [] do
      {:ok, for({:ok, instr} <- instructions, do: instr)}
    else
      {:error, Enum.join(errors, "\n")}
    end
  end

  defp parse_instruction(line) do
    tokens = tokenize(line)
    parse_action(tokens) || parse_assertion(tokens) || {:error, "unknown instruction: #{line}"}
  end

  # Actions: interactions and input
  defp parse_action(["click", selector]), do: {:ok, {:click, selector}}
  defp parse_action(["toggle", selector]), do: {:ok, {:toggle, selector}}
  defp parse_action(["select", selector, value]), do: {:ok, {:select, selector, value}}

  defp parse_action(["slide", selector, value]),
    do: {:ok, {:slide, selector, parse_number(value)}}

  defp parse_action(["type", selector, text]), do: {:ok, {:type_text, selector, text}}

  defp parse_action(["type", key]) when key in ~w[enter escape tab backspace],
    do: {:ok, {:type_key, key}}

  defp parse_action(["press", key]), do: {:ok, {:press, key}}
  defp parse_action(["release", key]), do: {:ok, {:release, key}}
  defp parse_action(["move", target]), do: {:ok, parse_move_target(target)}
  defp parse_action(["wait", ms]), do: {:ok, {:wait, String.to_integer(ms)}}
  defp parse_action(_tokens), do: nil

  # Assertions and captures
  defp parse_assertion(["expect", text]), do: {:ok, {:expect, text}}
  defp parse_assertion(["snapshot", name]), do: {:ok, {:snapshot, name}}
  defp parse_assertion(["screenshot", name]), do: {:ok, {:screenshot, name}}
  defp parse_assertion(["assert_text", selector, text]), do: {:ok, {:assert_text, selector, text}}
  defp parse_assertion(["assert_model", expr]), do: {:ok, {:assert_model, expr}}
  defp parse_assertion(_tokens), do: nil

  defp parse_move_target(target) do
    case String.split(target, ",") do
      [x_str, y_str] ->
        {:move_to, String.to_integer(String.trim(x_str)), String.to_integer(String.trim(y_str))}

      _ ->
        {:move, target}
    end
  end

  defp parse_number(str) do
    case Integer.parse(str) do
      {int, ""} -> int
      _ -> String.to_float(str)
    end
  end

  # Tokenizes a line, respecting quoted strings.
  # "click \"#foo\"" -> ["click", "#foo"]
  # "type \"#input\" \"hello world\"" -> ["type", "#input", "hello world"]
  defp tokenize(line) do
    ~r/"([^"]*)"|\S+/
    |> Regex.scan(line)
    |> Enum.map(fn
      [_full, inner] -> inner
      [bare] -> bare
    end)
  end
end
