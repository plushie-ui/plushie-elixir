defmodule Plushie.Docs.EffectsTest do
  use ExUnit.Case, async: true

  alias Plushie.Command
  alias Plushie.Event.EffectEvent

  # -- File open effect -------------------------------------------------------

  test "effects_file_open_returns_effect_command_test" do
    cmd =
      Plushie.Effect.file_open(:import,
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
    event = %EffectEvent{
      tag: :import,
      result: %Plushie.Effect.Result.FileOpened{path: "/tmp/notes.txt"}
    }

    assert %EffectEvent{
             tag: :import,
             result: %Plushie.Effect.Result.FileOpened{path: path}
           } = event

    assert path == "/tmp/notes.txt"
  end

  test "effects_cancelled_result_match_test" do
    event = %EffectEvent{tag: :import, result: %Plushie.Effect.Result.Cancelled{}}

    assert %EffectEvent{tag: :import, result: %Plushie.Effect.Result.Cancelled{}} = event
  end

  test "effects_error_result_match_test" do
    event = %EffectEvent{
      tag: :import,
      result: %Plushie.Effect.Result.Error{message: "unsupported"}
    }

    assert %EffectEvent{result: %Plushie.Effect.Result.Error{message: reason}} = event
    assert reason == "unsupported"
  end
end
