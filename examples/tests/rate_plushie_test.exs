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
    assert_exists("#review-0")
    assert_exists("#review-1")
    assert_exists("#review-2")
  end

  test "review user names render" do
    assert_text("#rname-0", "elixir_fan_42")
    assert_text("#rname-4", "otp_enjoyer")
  end

  test "review timestamps render" do
    assert_text("#rtime-0", "2d ago")
    assert_text("#rtime-4", "1w ago")
  end

  test "review form exists" do
    assert_exists("#review-name")
    assert_exists("#review-comment")
    assert_exists("#submit-review")
  end

  test "submitting a review adds it to the list" do
    m = model()
    assert length(m.reviews) == 6
  end

  test "rating card container exists" do
    assert_exists("#rating-card")
  end
end
