defmodule Toddy.Widget.QrCodeTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.QrCode

  describe "new/2" do
    test "creates a QR code struct with defaults" do
      qr = QrCode.new("qr1", "hello")
      assert qr.id == "qr1"
      assert qr.data == "hello"
      assert qr.cell_size == nil
      assert qr.cell_color == nil
      assert qr.background_color == nil
      assert qr.error_correction == nil
    end
  end

  describe "new/3 with opts" do
    test "applies keyword options" do
      qr = QrCode.new("qr2", "data", cell_size: 8, error_correction: :high)
      assert qr.cell_size == 8
      assert qr.error_correction == :high
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, fn ->
        QrCode.new("qr3", "data", bogus: true)
      end
    end
  end

  describe "builders" do
    test "cell_size/2" do
      qr = QrCode.new("q", "x") |> QrCode.cell_size(6)
      assert qr.cell_size == 6
    end

    test "cell_color/2 casts named atom" do
      qr = QrCode.new("q", "x") |> QrCode.cell_color(:red)
      assert is_binary(qr.cell_color)
    end

    test "cell_color/2 passes hex string" do
      qr = QrCode.new("q", "x") |> QrCode.cell_color("#ff0000")
      assert qr.cell_color == "#ff0000"
    end

    test "background_color/2 casts named atom" do
      qr = QrCode.new("q", "x") |> QrCode.background_color(:white)
      assert is_binary(qr.background_color)
    end

    test "error_correction/2" do
      qr = QrCode.new("q", "x") |> QrCode.error_correction(:quartile)
      assert qr.error_correction == :quartile
    end
  end

  describe "with_options/2" do
    test "empty list is identity" do
      qr = QrCode.new("q", "x")
      assert QrCode.with_options(qr, []) == qr
    end

    test "applies multiple options" do
      qr = QrCode.new("q", "x") |> QrCode.with_options(cell_size: 10, error_correction: :low)
      assert qr.cell_size == 10
      assert qr.error_correction == :low
    end
  end

  describe "build/1 (Widget protocol)" do
    test "produces a ui_node map" do
      node = QrCode.new("qr", "test data") |> QrCode.build()
      assert node.id == "qr"
      assert node.type == "qr_code"
      assert node.props["data"] == "test data"
      assert node.children == []
    end

    test "includes set props, omits nil props" do
      node =
        QrCode.new("qr", "data", cell_size: 8, error_correction: :high)
        |> QrCode.build()

      assert node.props["cell_size"] == 8
      assert node.props["error_correction"] == "high"
      refute Map.has_key?(node.props, "cell_color")
      refute Map.has_key?(node.props, "background_color")
    end

    test "color props are encoded" do
      node =
        QrCode.new("qr", "data")
        |> QrCode.cell_color("#112233")
        |> QrCode.background_color("#ffffff")
        |> QrCode.build()

      assert node.props["cell_color"] == "#112233"
      assert node.props["background_color"] == "#ffffff"
    end
  end
end
