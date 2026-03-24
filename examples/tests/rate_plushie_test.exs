defmodule Examples.RatePlushieTest do
  @moduledoc "Integration tests for the RatePlushie example using the test DSL."

  use Plushie.Test.Case, app: RatePlushie

  # -- Initial render ----------------------------------------------------------

  test "starts with zero rating" do
    assert model().rating == 0
  end

  test "starts in light mode" do
    m = model()
    assert m.toggle_progress == 0.0
    assert m.toggle_target == 0.0
  end

  test "starts with no validation errors" do
    assert model().errors == %{}
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

  test "name input has required a11y and is not invalid initially" do
    assert_a11y("#review-name", %{"required" => true, "invalid" => false})
    name_a11y = find!("#review-name") |> Plushie.Test.Element.a11y()
    refute Map.has_key?(name_a11y, "error_message")
  end

  test "comment editor has required a11y and is not invalid initially" do
    assert_a11y("#review-comment", %{"required" => true, "invalid" => false})
    comment_a11y = find!("#review-comment") |> Plushie.Test.Element.a11y()
    refute Map.has_key?(comment_a11y, "error_message")
  end

  test "no error text nodes rendered initially" do
    assert_not_exists("#review-name-error")
    assert_not_exists("#review-comment-error")
    assert_not_exists("#stars-error")
  end

  # -- Validation on submit (all fields empty) ---------------------------------

  test "submitting empty form shows all errors in the model" do
    click("#submit-review")

    errors = model().errors
    assert errors[:name] == "Name is required"
    assert errors[:comment] == "Review text is required"
    assert errors[:rating] == "Please select a rating"
  end

  test "submitting empty form renders error text nodes" do
    click("#submit-review")

    assert_text("#review-name-error", "Name is required")
    assert_text("#review-comment-error", "Review text is required")
    assert_text("#stars-error", "Please select a rating")
  end

  test "submitting empty form marks inputs as a11y invalid" do
    click("#submit-review")

    assert_a11y("#review-name", %{"invalid" => true})
    assert_a11y("#review-comment", %{"invalid" => true})
  end

  test "error text nodes have alert role for screen readers" do
    click("#submit-review")

    assert_a11y("#review-name-error", %{"role" => "alert", "live" => "polite"})
    assert_a11y("#review-comment-error", %{"role" => "alert", "live" => "polite"})
    assert_a11y("#stars-error", %{"role" => "alert", "live" => "polite"})
  end

  test "name input error_message points at its error text node" do
    click("#submit-review")

    # error_message is the fully-qualified scoped wire ID of the error text node
    name_a11y = find!("#review-name") |> Plushie.Test.Element.a11y()
    error_node = find!("#review-name-error")
    assert name_a11y["error_message"] == error_node.id
  end

  test "comment input error_message points at its error text node" do
    click("#submit-review")

    comment_a11y = find!("#review-comment") |> Plushie.Test.Element.a11y()
    error_node = find!("#review-comment-error")
    assert comment_a11y["error_message"] == error_node.id
  end

  # -- Validation on submit (partial fields) -----------------------------------

  test "submitting with only name filled shows comment and rating errors" do
    type_text("#review-name", "Lister")
    click("#submit-review")

    errors = model().errors
    assert errors[:name] == nil
    assert errors[:comment] == "Review text is required"
    assert errors[:rating] == "Please select a rating"
  end

  test "submitting with only comment filled shows name and rating errors" do
    type_text("#review-comment", "Smeg!")
    click("#submit-review")

    errors = model().errors
    assert errors[:name] == "Name is required"
    assert errors[:comment] == nil
    assert errors[:rating] == "Please select a rating"
  end

  test "whitespace-only name counts as empty" do
    type_text("#review-name", "   ")
    click("#submit-review")

    assert model().errors[:name] == "Name is required"
  end

  test "whitespace-only comment counts as empty" do
    type_text("#review-comment", "   ")
    click("#submit-review")

    assert model().errors[:comment] == "Review text is required"
  end

  # -- Clear-on-change ---------------------------------------------------------

  test "typing in name field clears its error" do
    click("#submit-review")
    assert model().errors[:name] != nil

    type_text("#review-name", "R")

    assert model().errors[:name] == nil
    assert_not_exists("#review-name-error")
  end

  test "typing in name field does not clear other errors" do
    click("#submit-review")
    type_text("#review-name", "R")

    assert model().errors[:comment] == "Review text is required"
    assert model().errors[:rating] == "Please select a rating"
  end

  test "typing in comment field clears its error" do
    click("#submit-review")
    assert model().errors[:comment] != nil

    type_text("#review-comment", "R")

    assert model().errors[:comment] == nil
    assert_not_exists("#review-comment-error")
  end

  test "typing in comment field does not clear other errors" do
    click("#submit-review")
    type_text("#review-comment", "R")

    assert model().errors[:name] == "Name is required"
    assert model().errors[:rating] == "Please select a rating"
  end

  test "a11y invalid clears when error is cleared by typing" do
    click("#submit-review")
    assert_a11y("#review-name", %{"invalid" => true})

    type_text("#review-name", "Cat")
    assert_a11y("#review-name", %{"invalid" => false})
  end

  test "error_message removed from a11y when error is cleared" do
    click("#submit-review")
    name_a11y = find!("#review-name") |> Plushie.Test.Element.a11y()
    assert Map.has_key?(name_a11y, "error_message")

    type_text("#review-name", "Cat")
    name_a11y = find!("#review-name") |> Plushie.Test.Element.a11y()
    refute Map.has_key?(name_a11y, "error_message")
  end

  # -- Successful submission ---------------------------------------------------

  test "does not add review when validation fails" do
    original_count = length(model().reviews)

    click("#submit-review")

    assert length(model().reviews) == original_count
  end

  test "submit via enter on name field also validates" do
    submit("#review-name")

    errors = model().errors
    assert errors[:name] == "Name is required"
    assert errors[:rating] == "Please select a rating"
  end

  # -- Form resets after success -----------------------------------------------
  # NOTE: Full successful submission requires a star rating click (canvas
  # interaction), which is not reliably testable through the mock backend.
  # The validation logic itself is thoroughly covered above. A headless or
  # windowed backend test could cover the full happy path.
end
