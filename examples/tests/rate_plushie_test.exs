defmodule Examples.RatePlushieTest do
  @moduledoc "Integration tests for the RatePlushie example using the test DSL."

  use Plushie.Test.Case, app: RatePlushie

  # -- Initial render ----------------------------------------------------------

  test "starts with zero rating in light mode" do
    assert model().rating == 0
    assert model().dark_mode == false
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

  test "rating card container exists" do
    assert_exists("#rating-card")
  end

  # -- A11y on form fields (initial state) -------------------------------------

  test "form fields are marked required and not invalid initially" do
    assert_a11y("#review-name", %{"required" => true, "invalid" => false})
    assert_a11y("#review-comment", %{"required" => true, "invalid" => false})
  end

  test "no error text rendered initially" do
    assert_not_exists("#review-name-error")
    assert_not_exists("#review-comment-error")
    assert_not_exists("#stars-error")
  end

  # -- Validation on submit (all fields empty) ---------------------------------

  test "submitting empty form shows all error messages" do
    click("#submit-review")

    assert_text("#review-name-error", "Name is required")
    assert_text("#review-comment-error", "Review text is required")
    assert_text("#stars-error", "Please select a rating")
  end

  test "submitting empty form marks inputs as invalid" do
    click("#submit-review")

    assert_a11y("#review-name", %{"invalid" => true})
    assert_a11y("#review-comment", %{"invalid" => true})
  end

  test "error messages are announced as alerts" do
    click("#submit-review")

    assert_a11y("#review-name-error", %{"role" => "alert", "live" => "polite"})
    assert_a11y("#review-comment-error", %{"role" => "alert", "live" => "polite"})
    assert_a11y("#stars-error", %{"role" => "alert", "live" => "polite"})
  end

  # -- Validation on submit (partial fields) -----------------------------------

  test "submitting with only name filled shows comment and rating errors" do
    type_text("#review-name", "Lister")
    click("#submit-review")

    assert_not_exists("#review-name-error")
    assert_text("#review-comment-error", "Review text is required")
    assert_text("#stars-error", "Please select a rating")
  end

  test "submitting with only comment filled shows name and rating errors" do
    type_text("#review-comment", "Smeg!")
    click("#submit-review")

    assert_text("#review-name-error", "Name is required")
    assert_not_exists("#review-comment-error")
    assert_text("#stars-error", "Please select a rating")
  end

  test "whitespace-only name counts as empty" do
    type_text("#review-name", "   ")
    click("#submit-review")

    assert_text("#review-name-error", "Name is required")
  end

  test "whitespace-only comment counts as empty" do
    type_text("#review-comment", "   ")
    click("#submit-review")

    assert_text("#review-comment-error", "Review text is required")
  end

  # -- Clear-on-change ---------------------------------------------------------

  test "typing in name field clears its error" do
    click("#submit-review")
    assert_exists("#review-name-error")

    type_text("#review-name", "R")

    assert_not_exists("#review-name-error")
    assert_a11y("#review-name", %{"invalid" => false})
  end

  test "typing in name field does not clear other errors" do
    click("#submit-review")
    type_text("#review-name", "R")

    assert_text("#review-comment-error", "Review text is required")
    assert_text("#stars-error", "Please select a rating")
  end

  test "typing in comment field clears its error" do
    click("#submit-review")
    assert_exists("#review-comment-error")

    type_text("#review-comment", "R")

    assert_not_exists("#review-comment-error")
    assert_a11y("#review-comment", %{"invalid" => false})
  end

  test "typing in comment field does not clear other errors" do
    click("#submit-review")
    type_text("#review-comment", "R")

    assert_text("#review-name-error", "Name is required")
    assert_text("#stars-error", "Please select a rating")
  end

  # -- Successful submission ---------------------------------------------------

  test "does not add review when validation fails" do
    original_count = length(model().reviews)

    click("#submit-review")

    assert length(model().reviews) == original_count
  end

  test "submit via enter on name field also validates" do
    submit("#review-name")

    assert_text("#review-name-error", "Name is required")
    assert_text("#stars-error", "Please select a rating")
  end

  # -- Form resets after success -----------------------------------------------
  # NOTE: Full successful submission requires a star rating click (canvas
  # interaction), which is not reliably testable through the mock backend.
  # The validation logic itself is thoroughly covered above. A headless or
  # windowed backend test could cover the full happy path.
end
