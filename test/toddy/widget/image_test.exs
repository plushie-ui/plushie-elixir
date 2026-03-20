defmodule Toddy.Widget.ImageTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Image

  # ---------------------------------------------------------------------------
  # Construction
  # ---------------------------------------------------------------------------

  describe "new/3 with file path source" do
    test "stores a string source as the image path" do
      img = Image.new("photo", "/tmp/cat.png")

      assert img.id == "photo"
      assert img.source == "/tmp/cat.png"
    end

    test "all optional fields default to nil" do
      img = Image.new("photo", "/tmp/cat.png")

      assert img.width == nil
      assert img.height == nil
      assert img.content_fit == nil
      assert img.rotation == nil
      assert img.opacity == nil
      assert img.border_radius == nil
      assert img.filter_method == nil
      assert img.expand == nil
      assert img.scale == nil
      assert img.crop == nil
    end
  end

  describe "new/3 with handle source" do
    test "stores a handle map for in-memory images" do
      img = Image.new("avatar", %{handle: "user_avatar"})

      assert img.id == "avatar"
      assert img.source == %{handle: "user_avatar"}
    end
  end

  # ---------------------------------------------------------------------------
  # Builder functions
  # ---------------------------------------------------------------------------

  describe "builder functions" do
    test "width/2 sets the width" do
      img = Image.new("i", "/a.png") |> Image.width(200)
      assert img.width == 200
    end

    test "height/2 sets the height" do
      img = Image.new("i", "/a.png") |> Image.height(150)
      assert img.height == 150
    end

    test "content_fit/2 sets the fit mode" do
      img = Image.new("i", "/a.png") |> Image.content_fit(:cover)
      assert img.content_fit == :cover
    end

    test "filter_method/2 sets the filter" do
      img = Image.new("i", "/a.png") |> Image.filter_method(:nearest)
      assert img.filter_method == :nearest
    end

    test "rotation/2 sets the angle" do
      img = Image.new("i", "/a.png") |> Image.rotation(45.0)
      assert img.rotation == 45.0
    end

    test "opacity/2 sets the opacity" do
      img = Image.new("i", "/a.png") |> Image.opacity(0.5)
      assert img.opacity == 0.5
    end

    test "border_radius/2 sets the radius" do
      img = Image.new("i", "/a.png") |> Image.border_radius(8)
      assert img.border_radius == 8
    end

    test "expand/2 sets the expand flag" do
      img = Image.new("i", "/a.png") |> Image.expand(true)
      assert img.expand == true
    end

    test "scale/2 sets the scale factor" do
      img = Image.new("i", "/a.png") |> Image.scale(2.0)
      assert img.scale == 2.0
    end

    test "crop/2 sets the crop rectangle" do
      crop = %{x: 10, y: 20, width: 100, height: 80}
      img = Image.new("i", "/a.png") |> Image.crop(crop)
      assert img.crop == crop
    end
  end

  # ---------------------------------------------------------------------------
  # build/1 -- node output
  # ---------------------------------------------------------------------------

  describe "build/1" do
    test "produces correct node with file path source" do
      node = Image.new("photo", "/images/logo.png") |> Image.build()

      assert node.id == "photo"
      assert node.type == "image"
      assert node.props[:source] == "/images/logo.png"
      assert node.children == []
    end

    test "produces correct node with handle source" do
      node = Image.new("dyn", %{handle: "generated"}) |> Image.build()

      assert node.props[:source] == %{handle: "generated"}
    end

    test "omits nil props" do
      node = Image.new("i", "/a.png") |> Image.build()

      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "content_fit")
      refute Map.has_key?(node.props, "filter_method")
      refute Map.has_key?(node.props, "rotation")
      refute Map.has_key?(node.props, "opacity")
      refute Map.has_key?(node.props, "border_radius")
      refute Map.has_key?(node.props, "crop")
    end

    test "includes all set options in props" do
      crop = %{x: 0, y: 0, width: 50, height: 50}

      node =
        Image.new("i", "/a.png",
          width: 320,
          height: 240,
          content_fit: :contain,
          filter_method: :nearest,
          rotation: 90,
          opacity: 0.8,
          border_radius: 4,
          expand: true,
          scale: 1.5,
          crop: crop
        )
        |> Image.build()

      assert node.props[:width] == 320
      assert node.props[:height] == 240
      assert node.props[:content_fit] == :contain
      assert node.props[:filter_method] == :nearest
      assert node.props[:rotation] == 90
      assert node.props[:opacity] == 0.8
      assert node.props[:border_radius] == 4
      assert node.props[:expand] == true
      assert node.props[:scale] == 1.5
      assert node.props[:crop] == crop
    end
  end

  # ---------------------------------------------------------------------------
  # with_options/2 -- error case
  # ---------------------------------------------------------------------------

  describe "with_options/2" do
    test "raises on unknown option" do
      assert_raise ArgumentError, fn ->
        Image.new("i", "/a.png", nonsense: 42)
      end
    end
  end
end
