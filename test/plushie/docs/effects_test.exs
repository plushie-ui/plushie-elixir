defmodule Plushie.Docs.EffectsTest do
  use ExUnit.Case, async: true

  alias Plushie.Command
  alias Plushie.Event.Effect

  # -- File open effect -------------------------------------------------------

  test "effects_file_open_returns_effect_command_test" do
    cmd =
      Plushie.Effects.file_open(
        title: "Choose a file",
        filters: [{"Text files", "*.txt"}, {"All files", "*"}]
      )

    assert %Command{type: :effect, payload: payload} = cmd
    assert payload.kind == "file_open"
    assert payload.opts.title == "Choose a file"
    assert payload.opts.filters == [{"Text files", "*.txt"}, {"All files", "*"}]
    assert is_binary(payload.id)
  end

  # -- Effect result event matching -------------------------------------------

  test "effects_ok_result_match_test" do
    event = %Effect{request_id: "ef_1", result: {:ok, %{path: "/tmp/notes.txt"}}}

    assert %Effect{result: {:ok, %{path: path}}} = event
    assert path == "/tmp/notes.txt"
  end

  test "effects_cancelled_result_match_test" do
    event = %Effect{request_id: "ef_1", result: :cancelled}

    assert %Effect{result: :cancelled} = event
  end

  test "effects_error_result_match_test" do
    event = %Effect{request_id: "ef_1", result: {:error, "unsupported"}}

    assert %Effect{result: {:error, reason}} = event
    assert reason == "unsupported"
  end
end
