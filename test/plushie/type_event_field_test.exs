defmodule Plushie.Type.EventFieldTest do
  @moduledoc """
  Tests for event field type parsing and built-in type modules.
  """

  use ExUnit.Case, async: true

  alias Plushie.Type
  alias Plushie.Type.{Key, KeyModifiers, MouseButton}

  # -- Type.parse_event_field/2 ------------------------------------------------

  describe "parse_event_field/2 with built-in types" do
    test "parses :float" do
      assert {:ok, 42} = Type.parse_event_field(:float, 42)
      assert {:ok, 3.14} = Type.parse_event_field(:float, 3.14)
      assert :error = Type.parse_event_field(:float, "42")
      assert :error = Type.parse_event_field(:float, nil)
    end

    test "parses :string" do
      assert {:ok, "hello"} = Type.parse_event_field(:string, "hello")
      assert {:ok, nil} = Type.parse_event_field(:string, nil)
      assert :error = Type.parse_event_field(:string, 42)
    end

    test "parses :boolean" do
      assert {:ok, true} = Type.parse_event_field(:boolean, true)
      assert {:ok, false} = Type.parse_event_field(:boolean, false)
      assert :error = Type.parse_event_field(:boolean, "true")
      assert :error = Type.parse_event_field(:boolean, nil)
    end

    test "parses :any" do
      assert {:ok, 42} = Type.parse_event_field(:any, 42)
      assert {:ok, "hello"} = Type.parse_event_field(:any, "hello")
      assert {:ok, nil} = Type.parse_event_field(:any, nil)
      assert {:ok, %{nested: true}} = Type.parse_event_field(:any, %{nested: true})
    end
  end

  describe "parse_event_field/2 with module types" do
    test "delegates to module parse/1" do
      assert {:ok, :arrow_right} = Type.parse_event_field(Key, "ArrowRight")
      assert {:ok, :left} = Type.parse_event_field(MouseButton, "left")
    end
  end

  describe "valid_event_type?/1" do
    test "recognises built-in atomic types" do
      assert Type.valid_event_type?(:float)
      assert Type.valid_event_type?(:string)
      assert Type.valid_event_type?(:boolean)
      assert Type.valid_event_type?(:any)
    end

    test "recognises module types with parse/1" do
      assert Type.valid_event_type?(Key)
      assert Type.valid_event_type?(KeyModifiers)
      assert Type.valid_event_type?(MouseButton)
    end

    test "rejects unknown atoms" do
      refute Type.valid_event_type?(:bogus)
    end

    test "rejects non-atoms" do
      refute Type.valid_event_type?("string")
      refute Type.valid_event_type?(42)
    end
  end

  # -- Type.Key ---------------------------------------------------------------

  describe "Type.Key.parse/1" do
    test "parses named keys to atoms" do
      assert {:ok, :escape} = Key.parse("Escape")
      assert {:ok, :arrow_right} = Key.parse("ArrowRight")
      assert {:ok, :tab} = Key.parse("Tab")
    end

    test "passes through single character keys as strings" do
      assert {:ok, "a"} = Key.parse("a")
      assert {:ok, "1"} = Key.parse("1")
    end

    test "rejects non-binary" do
      assert :error = Key.parse(nil)
      assert :error = Key.parse(42)
    end
  end

  # -- Type.KeyModifiers ------------------------------------------------------

  describe "Type.KeyModifiers.parse/1" do
    test "parses string-keyed modifier map" do
      assert {:ok, %Plushie.KeyModifiers{ctrl: true, shift: false}} =
               KeyModifiers.parse(%{"ctrl" => true, "shift" => false})
    end

    test "defaults missing fields to false" do
      assert {:ok, %Plushie.KeyModifiers{ctrl: false, shift: false, alt: false}} =
               KeyModifiers.parse(%{})
    end

    test "handles nil" do
      assert {:ok, %Plushie.KeyModifiers{}} = KeyModifiers.parse(nil)
    end

    test "rejects non-map/non-nil" do
      assert :error = KeyModifiers.parse("invalid")
    end
  end

  # -- Type.MouseButton -------------------------------------------------------

  describe "Type.MouseButton.parse/1" do
    test "parses known button strings" do
      assert {:ok, :left} = MouseButton.parse("left")
      assert {:ok, :right} = MouseButton.parse("right")
      assert {:ok, :middle} = MouseButton.parse("middle")
      assert {:ok, :back} = MouseButton.parse("back")
      assert {:ok, :forward} = MouseButton.parse("forward")
    end

    test "defaults nil to left" do
      assert {:ok, :left} = MouseButton.parse(nil)
    end

    test "rejects unknown strings" do
      assert :error = MouseButton.parse("unknown")
    end

    test "rejects non-binary" do
      assert :error = MouseButton.parse(42)
    end
  end
end
