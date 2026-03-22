defmodule Examples.RatePlushieTest do
  @moduledoc "Integration tests for the RatePlushie example using the test DSL."

  use Plushie.Test.Case, app: RatePlushie

  test "starts with zero rating" do
    assert model().rating == 0
  end

  test "starts in light mode" do
    m = model()
    assert m.toggle_progress == 0.0
    assert m.toggle_target == 0.0
  end

  test "heading text exists" do
    assert_text("#heading", "Rate Plushie")
  end

  test "star rating canvas exists" do
    assert_exists("#stars")
  end

  test "theme toggle canvas exists" do
    assert_exists("#theme-toggle")
  end

  test "prompt text exists" do
    assert_text("#prompt", "How would you rate Plushie?")
  end

  test "toggle label exists" do
    assert_text("#toggle-label", "Dark humor")
  end

  test "reviews heading exists" do
    assert_text("#reviews-heading", "Reviews")
  end

  test "review containers render" do
    assert_exists("#review-elixir_fan_42")
    assert_exists("#review-jose_v")
    assert_exists("#review-rustacean")
    assert_exists("#review-web_refugee")
    assert_exists("#review-otp_enjoyer")
    assert_exists("#review-electron_mass")
  end

  test "review user names render" do
    assert_text("#elixir_fan_42-name", "elixir_fan_42")
    assert_text("#otp_enjoyer-name", "otp_enjoyer")
  end

  test "review timestamps render" do
    assert_text("#elixir_fan_42-time", "2d ago")
    assert_text("#otp_enjoyer-time", "1w ago")
  end

  test "rating card container exists" do
    assert_exists("#rating-card")
  end
end
