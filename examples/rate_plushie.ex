defmodule RatePlushie do
  @moduledoc """
  App rating page for Plushie.

  Demonstrates custom canvas widgets (StarRating, ThemeToggle) composed
  with styled containers using the full DSL. The "Dark humor" toggle
  animates the emoji and flips the entire page theme.

      mix plushie.gui RatePlushie
  """

  use Plushie.App

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
      hover_star: nil,
      toggle_progress: 0.0,
      toggle_target: 0.0,
      reviews: @initial_reviews,
      review_name: "",
      review_comment: ""
    }
  end

  def update(model, event) do
    alias Plushie.Event.{Widget, Timer}

    case event do
      %Widget{type: :canvas_element_click, id: "stars", data: %{"element_id" => "star-" <> n}} ->
        %{model | rating: String.to_integer(n) + 1}

      %Widget{type: :canvas_element_enter, id: "stars", data: %{"element_id" => "star-" <> n}} ->
        %{model | hover_star: String.to_integer(n) + 1}

      %Widget{type: :canvas_element_leave, id: "stars"} ->
        %{model | hover_star: nil}

      %Widget{type: :canvas_element_click, id: "theme-toggle"} ->
        target = if model.toggle_target == 0.0, do: 1.0, else: 0.0
        %{model | toggle_target: target}

      %Widget{type: :input, id: "review-name", value: v} ->
        %{model | review_name: v}

      %Widget{type: :input, id: "review-comment", value: v} ->
        %{model | review_comment: v}

      %Widget{type: :click, id: "submit-review"} -> submit_review(model)
      %Widget{type: :submit, id: "review-name"} -> submit_review(model)

      %Timer{tag: :animate} ->
        %{model | toggle_progress: approach(model.toggle_progress, model.toggle_target, 0.06)}

      _ -> model
    end
  end

  defp submit_review(model) do
    name = String.trim(model.review_name)
    comment = String.trim(model.review_comment)

    if name != "" and comment != "" and model.rating > 0 do
      review = %{stars: model.rating, user: name, time: "just now", text: comment}
      %{model | reviews: [review | model.reviews], review_name: "", review_comment: "", rating: 0}
    else
      model
    end
  end

  def subscribe(model) do
    if model.toggle_progress != model.toggle_target do
      [Plushie.Subscription.every(16, :animate)]
    else
      []
    end
  end

  # -- View --------------------------------------------------------------------

  def view(model) do
    import Plushie.UI

    p = smoothstep(model.toggle_progress)
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

            text("heading", "Rate Plushie", size: 28, a11y: %{role: :heading, level: 1})
            rating_card(model, p, t)
            text("reviews-heading", "Reviews", size: 20, a11y: %{role: :heading, level: 2})
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

        StarRating.render("stars", model.rating,
          hover: model.hover_star,
          theme_progress: p
        )

        rule()
        review_form(model, t)
        theme_row(model, t)
      end
    end
  end

  # -- Review form -------------------------------------------------------------

  defp review_form(model, _t) do
    import Plushie.UI

    column id: "review-form", spacing: 12, width: :fill do
      text_input "review-name", model.review_name do
        placeholder "Your name"
        a11y %{label: "Your name"}
      end

      text_editor "review-comment", model.review_comment do
        placeholder "Write your review..."
        height 80
        a11y %{label: "Review text"}
      end

      button("submit-review", "Submit Review")
    end
  end

  # -- Theme toggle row --------------------------------------------------------

  defp theme_row(model, t) do
    import Plushie.UI

    row id: "theme-row", align_y: :center do
      space(id: "theme-spacer", width: :fill)
      text("toggle-label", "Dark humor", color: t.text_secondary)
      ThemeToggle.render("theme-toggle", model.toggle_progress)
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
        StarRating.render("rstars-#{i}", review.stars,
          readonly: true, scale: 0.4, theme_progress: p
        )
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
      text_muted: fade({170, 170, 170}, {85, 85, 119}, p)
    }
  end

  defp fade({r1, g1, b1}, {r2, g2, b2}, t) do
    r = round(r1 + (r2 - r1) * t)
    g = round(g1 + (g2 - g1) * t)
    b = round(b1 + (b2 - b1) * t)
    "#" <> hex(r) <> hex(g) <> hex(b)
  end

  defp hex(n), do: n |> Integer.to_string(16) |> String.pad_leading(2, "0")
  defp smoothstep(t) when t <= 0.0, do: 0.0
  defp smoothstep(t) when t >= 1.0, do: 1.0
  defp smoothstep(t), do: t * t * (3 - 2 * t)

  defp approach(current, target, step) do
    cond do
      current < target -> min(current + step, target)
      current > target -> max(current - step, target)
      true -> current
    end
  end
end
