defmodule Plushie.Event.EventTypeTest do
  @moduledoc """
  Tests for the EventType behaviour and built-in type modules.
  """

  use ExUnit.Case, async: true

  alias Plushie.Event.EventType
  alias Plushie.Type.{Key, KeyModifiers, MouseButton}

  # -- EventType.parse_field/2 ------------------------------------------------

  describe "parse_field/2 with built-in types" do
    test "parses :number" do
      assert {:ok, 42} = EventType.parse_field(:number, 42)
      assert {:ok, 3.14} = EventType.parse_field(:number, 3.14)
      assert :error = EventType.parse_field(:number, "42")
      assert :error = EventType.parse_field(:number, nil)
    end

    test "parses :string" do
      assert {:ok, "hello"} = EventType.parse_field(:string, "hello")
      assert {:ok, nil} = EventType.parse_field(:string, nil)
      assert :error = EventType.parse_field(:string, 42)
    end

    test "parses :boolean" do
      assert {:ok, true} = EventType.parse_field(:boolean, true)
      assert {:ok, false} = EventType.parse_field(:boolean, false)
      assert :error = EventType.parse_field(:boolean, "true")
      assert :error = EventType.parse_field(:boolean, nil)
    end

    test "parses :any" do
      assert {:ok, 42} = EventType.parse_field(:any, 42)
      assert {:ok, "hello"} = EventType.parse_field(:any, "hello")
      assert {:ok, nil} = EventType.parse_field(:any, nil)
      assert {:ok, %{nested: true}} = EventType.parse_field(:any, %{nested: true})
    end
  end

  describe "parse_field/2 with module types" do
    test "delegates to module parse/1" do
      assert {:ok, :arrow_right} = EventType.parse_field(Key, "ArrowRight")
      assert {:ok, :left} = EventType.parse_field(MouseButton, "left")
    end
  end

  describe "valid_type?/1" do
    test "recognises built-in atomic types" do
      assert EventType.valid_type?(:number)
      assert EventType.valid_type?(:string)
      assert EventType.valid_type?(:boolean)
      assert EventType.valid_type?(:any)
    end

    test "recognises module types implementing the behaviour" do
      assert EventType.valid_type?(Key)
      assert EventType.valid_type?(KeyModifiers)
      assert EventType.valid_type?(MouseButton)
    end

    test "rejects unknown atoms" do
      refute EventType.valid_type?(:bogus)
    end

    test "rejects non-atoms" do
      refute EventType.valid_type?("string")
      refute EventType.valid_type?(42)
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
