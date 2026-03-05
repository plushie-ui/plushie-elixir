defmodule Julep.FeaturesTest do
  use ExUnit.Case, async: true

  alias Julep.Features

  describe "all_iced_features/0" do
    test "returns list of all known features" do
      features = Features.all_iced_features()
      assert is_list(features)
      assert :image in features
      assert :svg in features
      assert :canvas in features
      assert :markdown in features
      assert :highlighter in features
      assert :sysinfo in features
      assert :qr_code in features
    end
  end

  describe "iced_features/0" do
    test "defaults to :all when no config is set" do
      assert Features.iced_features() == :all
    end
  end

  describe "iced_feature_enabled?/1" do
    test "returns true for any feature when config is :all" do
      # Default config is :all
      assert Features.iced_feature_enabled?(:image)
      assert Features.iced_feature_enabled?(:qr_code)
      assert Features.iced_feature_enabled?(:nonexistent)
    end
  end

  describe "cargo_feature_name/1" do
    test "converts atom to cargo feature name" do
      assert Features.cargo_feature_name(:image) == "widget-image"
      assert Features.cargo_feature_name(:qr_code) == "widget-qr-code"
      assert Features.cargo_feature_name(:canvas) == "widget-canvas"
    end
  end
end
