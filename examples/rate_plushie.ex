defmodule RatePlushie do
  @moduledoc """
  App rating page for Plushie.

  Demonstrates custom canvas widgets (StarRating, ThemeToggle) composed
  with styled containers using the full DSL. The "Dark humor" toggle
  animates the emoji and flips the entire page theme.

  The review form showcases form validation with:
  - Per-field error state tracked in the model
  - Visual error styling via `StyleMap` (border + background tint)
  - Accessible error wiring via `a11y` (`required`, `invalid`, `error_message`)
  - Validate-on-submit with clear-on-change for responsive UX

      mix plushie.gui RatePlushie
  """

  use Plushie.App

  alias Plushie.Type.{Border, StyleMap}

  @initial_reviews [
    %{stars: 5, user: "elixir_fan_42", time: "2d ago",
      text: "Finally, native GUIs that don't make me want to cry."},
    %{stars: 5, user: "beam_me_up", time: "3d ago",
      text: "The Elm architecture feels right at home here."},
    %{stars: 4, user: "rustacean", time: "5d ago",
      text: "Solid Iced wrapper. Docked a star because I had to write Elixir."},
    %{stars: 3, user: "web_refugee", time: "1w ago",
      text: "Where is my CSS grid? Also it works perfectly. Three stars."},
    %{stars: 5, user: "otp_enjoyer", time: "1w ago",
      text: "Let it crash, but make it beautiful."},
    %{stars: 1, user: "electron_mass", time: "2w ago",
      text: "No browser engine. No JavaScript runtime. What am I even paying for?"}
  ]

  # -- Init / Update / Subscribe -----------------------------------------------

  def init(_opts) do
    %{
      rating: 0,
      dark_mode: false,
      reviews: @initial_reviews,
      review_name: "",
      review_comment: "",
      errors: %{}
    }
  end

  def update(model, event) do
    alias Plushie.Event.WidgetEvent

    # StarRating and ThemeToggle are canvas_widgets that emit semantic
    # events. The widget ID is un-scoped here because they're direct
    # children of the page container (named containers scope their
    # children, but the events carry the widget's own ID).
    case event do
      # Star rating emits :select with the number of stars.
      %WidgetEvent{type: :select, id: "stars", value: stars} ->
        %{model | rating: stars, errors: Map.delete(model.errors, :rating)}

      # Theme toggle emits built-in :toggle with the new state.
      # Animation is managed internally by the canvas_widget.
      %WidgetEvent{type: :toggle, id: "theme-toggle", value: dark?} ->
        %{model | dark_mode: dark?}

      %WidgetEvent{type: :input, id: "review-name", value: v} ->
        %{model | review_name: v, errors: Map.delete(model.errors, :name)}

      %WidgetEvent{type: :input, id: "review-comment", value: v} ->
        %{model | review_comment: v, errors: Map.delete(model.errors, :comment)}

      %WidgetEvent{type: :click, id: "submit-review"} -> submit_review(model)
      %WidgetEvent{type: :submit, id: "review-name"} -> submit_review(model)

      _ -> model
    end
  end

  defp submit_review(model) do
    errors = validate_review(model)

    if errors == %{} do
      name = String.trim(model.review_name)
      comment = String.trim(model.review_comment)
      review = %{stars: model.rating, user: name, time: "just now", text: comment}

      %{model | reviews: [review | model.reviews], review_name: "", review_comment: "", rating: 0, errors: %{}}
    else
      %{model | errors: errors}
    end
  end

  defp validate_review(model) do
    %{}
    |> validate_required(:name, model.review_name, "Name is required")
    |> validate_required(:comment, model.review_comment, "Review text is required")
    |> validate_rating(model.rating)
  end

  defp validate_required(errors, key, value, message) do
    if String.trim(value) == "", do: Map.put(errors, key, message), else: errors
  end

  defp validate_rating(errors, rating) when rating > 0, do: errors
  defp validate_rating(errors, _rating), do: Map.put(errors, :rating, "Please select a rating")

  def subscribe(_model), do: []

  # -- View --------------------------------------------------------------------

  def view(model) do
    import Plushie.UI

    p = if model.dark_mode, do: 1.0, else: 0.0
    t = theme(p)

    page_theme =
      Plushie.Type.Theme.custom("rate-plushie",
        background: t.page_bg,
        text: t.text,
        primary: fade({59, 130, 246}, {139, 92, 246}, p)
      )

    window "main", title: "Rate Plushie" do
      themer "page-theme", theme: page_theme do
        container "page" do
          padding do
            top 32
            bottom 32
            left 24
            right 24
          end

          background(t.page_bg)
          width(:fill)
          height(:fill)

          column do
            spacing 24
            width :fill

            text("heading", "Rate Plushie", size: 28, color: t.text, a11y: %{role: :heading, level: 1})
            rating_card(model, p, t)
            text("reviews-heading", "Reviews", size: 20, color: t.text, a11y: %{role: :heading, level: 2})
            reviews_list(model.reviews, p, t)
          end
        end
      end
    end
  end

  # -- Rating card -------------------------------------------------------------

  defp rating_card(model, p, t) do
    import Plushie.UI

    container "rating-card" do
      padding 24
      width :fill
      border do
        width 1
        color t.card_border
        rounded 12
      end
      background t.card_bg

      column do
        spacing 20

        text("prompt", "How would you rate Plushie?", size: 14, color: t.text_secondary)

        column id: "stars-group", spacing: 4 do
          StarRating.new("stars", rating: model.rating, theme_progress: p)

          if error = model.errors[:rating] do
            text("stars-error", error,
              size: 12,
              color: t.error_text,
              a11y: %{role: :alert, live: :polite}
            )
          end
        end

        rule()
        review_form(model, t)
        theme_row(model, t)
      end
    end
  end

  # -- Review form -------------------------------------------------------------

  defp review_form(model, t) do
    import Plushie.UI

    column id: "review-form", spacing: 12, width: :fill do
      column id: "name-field", spacing: 4, width: :fill do
        text_input "review-name", model.review_name do
          placeholder "Your name"
          on_submit true
          style input_style(model.errors[:name], t)

          a11y %{
            label: "Your name",
            required: true,
            invalid: model.errors[:name] != nil,
            error_message: if(model.errors[:name], do: "review-name-error")
          }
        end

        if error = model.errors[:name] do
          text("review-name-error", error,
            size: 12,
            color: t.error_text,
            a11y: %{role: :alert, live: :polite}
          )
        end
      end

      column id: "comment-field", spacing: 4, width: :fill do
        text_editor "review-comment", model.review_comment do
          placeholder "Write your review..."
          height 80
          style input_style(model.errors[:comment], t)

          a11y %{
            label: "Review text",
            required: true,
            invalid: model.errors[:comment] != nil,
            error_message: if(model.errors[:comment], do: "review-comment-error")
          }
        end

        if error = model.errors[:comment] do
          text("review-comment-error", error,
            size: 12,
            color: t.error_text,
            a11y: %{role: :alert, live: :polite}
          )
        end
      end

      button("submit-review", "Submit Review")
    end
  end

  defp input_style(nil, _t), do: :default

  defp input_style(_error, t) do
    error_border = Border.new() |> Border.color(t.error_border) |> Border.width(2) |> Border.rounded(4)

    StyleMap.new()
    |> StyleMap.border(error_border)
    |> StyleMap.background(t.error_bg)
    |> StyleMap.focused(%{border: error_border})
  end

  # -- Theme toggle row --------------------------------------------------------

  defp theme_row(_model, t) do
    import Plushie.UI

    row id: "theme-row", align_y: :center do
      space(id: "theme-spacer", width: :fill)
      text("toggle-label", "Dark humor", color: t.text_secondary)
      ThemeToggle.new("theme-toggle")
    end
  end

  # -- Reviews list ------------------------------------------------------------

  defp reviews_list(reviews, p, t) do
    import Plushie.UI

    column id: "reviews", spacing: 0, width: :fill do
      for {review, i} <- Enum.with_index(reviews) do
        [
          if i > 0 do
            rule(id: "sep-#{i}")
          end,
          review_card(review, i, p, t)
        ]
      end
    end
  end

  defp review_card(review, i, p, t) do
    import Plushie.UI

    column id: "review-#{i}", spacing: 4, padding: 12, width: :fill do
      row id: "rhdr-#{i}", spacing: 8, align_y: :center do
        StarRating.new("rstars-#{i}", rating: review.stars, readonly: true, scale: 0.4, theme_progress: p)
        text("rname-#{i}", review.user, size: 12, color: t.text_secondary)
        space(id: "rsp-#{i}", width: :fill)
        text("rtime-#{i}", review.time, size: 12, color: t.text_muted)
      end

      text("rtext-#{i}", "\u{201C}#{review.text}\u{201D}", size: 14, color: t.text)
    end
  end

  # -- Theme -------------------------------------------------------------------

  defp theme(p) do
    %{
      page_bg: fade({248, 248, 250}, {19, 19, 31}, p),
      card_bg: fade({255, 255, 255}, {28, 28, 50}, p),
      card_border: fade({224, 224, 224}, {42, 42, 74}, p),
      text: fade({26, 26, 26}, {240, 240, 245}, p),
      text_secondary: fade({102, 102, 102}, {153, 153, 187}, p),
      text_muted: fade({170, 170, 170}, {85, 85, 119}, p),
      error_text: fade({185, 28, 28}, {255, 100, 100}, p),
      error_border: fade({220, 38, 38}, {255, 80, 80}, p),
      error_bg: fade({254, 242, 242}, {50, 20, 20}, p)
    }
  end

  defp fade({r1, g1, b1}, {r2, g2, b2}, t) do
    r = round(r1 + (r2 - r1) * t)
    g = round(g1 + (g2 - g1) * t)
    b = round(b1 + (b2 - b1) * t)
    "#" <> hex(r) <> hex(g) <> hex(b)
  end

  defp hex(n), do: n |> Integer.to_string(16) |> String.pad_leading(2, "0")
end
