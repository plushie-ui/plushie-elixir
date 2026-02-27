defmodule Julep.Test.Script do
  @moduledoc """
  Parser for `.julep` test scripts.

  The `.julep` format is a superset of iced's `.ice` test script format,
  adding Julep-specific instructions like `assert_text` and `assert_model`.

  ## Format

      app: MyApp.Counter
      viewport: 800x600
      theme: dark
      backend: sim
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
        backend = parse_backend(Map.get(fields, "backend", "sim"))
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

  defp parse_backend("sim"), do: :sim
  defp parse_backend("headless"), do: :headless
  defp parse_backend("full"), do: :full
  defp parse_backend(_), do: :sim

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
    case tokenize(line) do
      ["click", selector] ->
        {:ok, {:click, selector}}

      ["type", selector, text] ->
        {:ok, {:type_text, selector, text}}

      ["type", key] when key in ~w[enter escape tab backspace] ->
        {:ok, {:type_key, key}}

      ["press", key] ->
        {:ok, {:press, key}}

      ["release", key] ->
        {:ok, {:release, key}}

      ["move", target] ->
        case String.split(target, ",") do
          [x_str, y_str] ->
            {:ok,
             {:move_to, String.to_integer(String.trim(x_str)),
              String.to_integer(String.trim(y_str))}}

          _ ->
            {:ok, {:move, target}}
        end

      ["assert_model", expr] ->
        {:ok, {:assert_model, expr}}

      ["expect", text] ->
        {:ok, {:expect, text}}

      ["snapshot", name] ->
        {:ok, {:snapshot, name}}

      ["screenshot", name] ->
        {:ok, {:screenshot, name}}

      ["assert_text", selector, text] ->
        {:ok, {:assert_text, selector, text}}

      ["wait", ms] ->
        {:ok, {:wait, String.to_integer(ms)}}

      _ ->
        {:error, "unknown instruction: #{line}"}
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
