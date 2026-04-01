defmodule Plushie.Docs.EffectsTest do
  use ExUnit.Case, async: true

  alias Plushie.Command
  alias Plushie.Event.Effect

  # -- File open effect -------------------------------------------------------

  test "effects_file_open_returns_effect_command_test" do
    cmd =
      Plushie.Effects.file_open(:import,
        title: "Choose a file",
        filters: [{"Text files", "*.txt"}, {"All files", "*"}]
      )

    assert %Command{type: :effect, payload: payload} = cmd
    assert payload.tag == :import
    assert payload.kind == "file_open"
    assert payload.opts.title == "Choose a file"
    assert payload.opts.filters == [{"Text files", "*.txt"}, {"All files", "*"}]
    assert is_binary(payload.id)
  end

  # -- Effect result event matching -------------------------------------------

  test "effects_ok_result_match_test" do
    event = %Effect{tag: :import, result: {:ok, %{path: "/tmp/notes.txt"}}}

    assert %Effect{tag: :import, result: {:ok, %{path: path}}} = event
    assert path == "/tmp/notes.txt"
  end

  test "effects_cancelled_result_match_test" do
    event = %Effect{tag: :import, result: :cancelled}

    assert %Effect{tag: :import, result: :cancelled} = event
  end

  test "effects_error_result_match_test" do
    event = %Effect{tag: :import, result: {:error, "unsupported"}}

    assert %Effect{result: {:error, reason}} = event
    assert reason == "unsupported"
  end
end
