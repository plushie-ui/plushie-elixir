defmodule Plushie.Event.DiagnosticTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.Diagnostic

  describe "decode!/1" do
    test "decodes duplicate_id into the typed struct" do
      assert %Diagnostic.DuplicateId{id: "main#form/email", window_id: "main"} =
               Diagnostic.decode!(%{
                 "kind" => "duplicate_id",
                 "id" => "main#form/email",
                 "window_id" => "main"
               })
    end

    test "decodes update_panicked with consecutive counter" do
      assert %Diagnostic.UpdatePanicked{consecutive: 3, message: "boom"} =
               Diagnostic.decode!(%{
                 "kind" => "update_panicked",
                 "consecutive" => 3,
                 "message" => "boom"
               })
    end

    test "decodes required_widgets_missing with list" do
      assert %Diagnostic.RequiredWidgetsMissing{missing: ["alpha", "beta"]} =
               Diagnostic.decode!(%{
                 "kind" => "required_widgets_missing",
                 "missing" => ["alpha", "beta"]
               })
    end

    test "decodes dispatch_loop_exceeded" do
      assert %Diagnostic.DispatchLoopExceeded{depth: 101, limit: 100} =
               Diagnostic.decode!(%{
                 "kind" => "dispatch_loop_exceeded",
                 "depth" => 101,
                 "limit" => 100
               })
    end

    test "decodes buffer_overflow" do
      assert %Diagnostic.BufferOverflow{size: 80_000_000, limit: 67_108_864} =
               Diagnostic.decode!(%{
                 "kind" => "buffer_overflow",
                 "size" => 80_000_000,
                 "limit" => 67_108_864
               })
    end

    test "raises on unknown kind" do
      assert_raise ArgumentError, ~r/unknown diagnostic kind/, fn ->
        Diagnostic.decode!(%{"kind" => "never_heard_of_it"})
      end
    end

    test "raises on non-map payload" do
      assert_raise ArgumentError, fn -> Diagnostic.decode!("string") end
    end

    test "known_kinds/0 includes every variant we decode" do
      kinds = Diagnostic.known_kinds()
      assert "duplicate_id" in kinds
      assert "update_panicked" in kinds
      assert "dispatch_loop_exceeded" in kinds
      assert "buffer_overflow" in kinds
    end
  end
end
