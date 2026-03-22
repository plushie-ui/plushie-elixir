defmodule RatePlushie do
  @moduledoc """
  App rating page for Plushie.

  Demonstrates custom canvas widgets (StarRating, ThemeToggle) composed
  with styled containers using the full DSL. The "Dark humor" toggle
  animates the emoji and flips the entire page theme.

      mix plushie.gui RatePlushie
  """

  @behaviour Plushie.App

  @reviews [
    %{stars: 5, user: "elixir_fan_42", time: "2d ago",
      text: "Finally, native GUIs that don't make me want to cry."},
    %{stars: 5, user: "jose_v", time: "3d ago",
      text: "The Elm architecture feels right at home here."},
    %{stars: 4, user: "rustacean", time: "5d ago",
      text: "Solid Iced wrapper. Docked a star because I had to write Elixir."},
    %{stars: 3, user: "web_refugee", time: "1w ago",
      text: "Where is my CSS grid? Also it works perfectly. Three stars."},
    %{stars: 5, user: "otp_enjoyer", time: "1w ago",
      text: "Let it crash, but make it beautiful."},
    %{stars: 1, user: "electron_mass", time: "2w ago",
      text: "Only uses 12MB of RAM. How am I supposed to justify my hardware?"}
  ]

  def init(_opts) do
    %{rating: 0, hover_star: nil, toggle_progress: 0.0, toggle_target: 0.0}
  end

  def update(model, event) do
    alias Plushie.Event.{Widget, Timer, Key}

    case event do
      %Widget{type: :canvas_shape_click, id: "stars", data: %{"shape_id" => "star-" <> n}} ->
        %{model | rating: String.to_integer(n) + 1}

      %Widget{type: :canvas_shape_enter, id: "stars", data: %{"shape_id" => "star-" <> n}} ->
        %{model | hover_star: String.to_integer(n) + 1}

      %Widget{type: :canvas_shape_leave, id: "stars"} ->
        %{model | hover_star: nil}

      %Widget{type: :canvas_shape_click, id: "theme-toggle"} ->
        target = if model.toggle_target == 0.0, do: 1.0, else: 0.0
        %{model | toggle_target: target}

      %Timer{tag: :animate} ->
        progress = approach(model.toggle_progress, model.toggle_target, 0.06)
        %{model | toggle_progress: progress}

      %Key{key: "ArrowRight"} ->
        %{model | rating: min(model.rating + 1, 5)}

      %Key{key: "ArrowLeft"} ->
        %{model | rating: max(model.rating - 1, 0)}

      _ ->
        model
    end
  end

  def subscribe(model) do
    subs = [Plushie.Subscription.on_key_press(:key)]

    if model.toggle_progress != model.toggle_target do
      [Plushie.Subscription.every(16, :animate) | subs]
    else
      subs
    end
  end

  def view(model) do
    import Plushie.UI

    dark = model.toggle_progress >= 0.5
    t = theme(dark)

    window "main", title: "Rate Plushie" do
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

        scrollable "scroll" do
          column do
            spacing 24
            width :fill
            align_x :center

            text("heading", "Rate Plushie", size: 28, color: t.text)

            container "rating-card" do
              padding 24
              width :fill

              border do
                width 1
                color(t.card_border)
                rounded 12
              end

              background(t.card_bg)

              column do
                spacing 20

                text("prompt", "How would you rate Plushie?",
                  size: 14, color: t.text_secondary
                )

                StarRating.render("stars", model.rating,
                  hover: model.hover_star, dark: dark
                )

                rule()

                row do
                  align_y :center
                  text("toggle-label", "Dark humor", color: t.text_secondary)
                  space(width: :fill)
                  ThemeToggle.render("theme-toggle", model.toggle_progress)
                end
              end
            end

            text("reviews-heading", "Reviews", size: 20, color: t.text)

            container "reviews" do
              border do
                width 1
                color(t.card_border)
                rounded 12
              end

              background(t.card_bg)
              width :fill
              clip

              column do
                for {review, i} <- Enum.with_index(@reviews) do
                  [
                    if i > 0 do
                      container("sep-#{i}",
                        height: 1, width: :fill, background: t.separator
                      )
                    end,
                    review_row(review, t)
                  ]
                end
              end
            end
          end
        end
      end
    end
  end

  defp review_row(review, t) do
    import Plushie.UI

    container "review-#{review.user}" do
      padding do
        top 14
        bottom 14
        left 20
        right 20
      end

      width :fill

      column do
        spacing 6

        row do
          spacing 8

          text("#{review.user}-stars", star_text(review.stars),
            size: 12, color: "#f59e0b"
          )

          text("#{review.user}-name", review.user,
            size: 12, color: t.text_secondary
          )

          space(width: :fill)

          text("#{review.user}-time", review.time,
            size: 12, color: t.text_muted
          )
        end

        text("#{review.user}-text", "\u{201C}#{review.text}\u{201D}",
          size: 14, color: t.text
        )
      end
    end
  end

  defp star_text(n) do
    String.duplicate("\u{2605}", n) <> String.duplicate("\u{2606}", 5 - n)
  end

  defp theme(true) do
    %{
      page_bg: "#13131f",
      card_bg: "#1c1c32",
      card_border: "#2a2a4a",
      separator: "#2a2a4a",
      text: "#f0f0f5",
      text_secondary: "#9999bb",
      text_muted: "#555577"
    }
  end

  defp theme(false) do
    %{
      page_bg: "#f8f8fa",
      card_bg: "#ffffff",
      card_border: "#e0e0e0",
      separator: "#eeeeee",
      text: "#1a1a1a",
      text_secondary: "#666666",
      text_muted: "#aaaaaa"
    }
  end

  defp approach(current, target, step) do
    cond do
      current < target -> min(current + step, target)
      current > target -> max(current - step, target)
      true -> current
    end
  end
end
