defmodule StarRating do
  @moduledoc """
  Canvas-based star rating widget.

  Renders 5 stars as a radio group. Interactive by default (click to
  rate, hover to preview, Tab/arrow to navigate, Enter/Space to select).
  Pass `readonly: true` for a display-only version.

      # Interactive (full size)
      StarRating.render("my-rating", model.rating,
        hover: model.hover_star, theme_progress: p)

      # Read-only (small, for review display)
      StarRating.render("review-stars", 4, readonly: true, scale: 0.5)

  Events:
  - `canvas_element_click` with element_id `"star-0"` through `"star-4"`
  - `canvas_element_enter`/`canvas_element_leave` for hover
  - `canvas_element_focused` with element_id for keyboard focus
  """

  import Plushie.Canvas.Shape, only: [move_to: 2, line_to: 2, close: 0]

  @doc "Renders a star rating canvas widget."
  def render(id, rating, opts \\ []) do
    import Plushie.UI

    hover = Keyword.get(opts, :hover)
    theme_progress = Keyword.get(opts, :theme_progress, 0.0)
    readonly = Keyword.get(opts, :readonly, false)
    scale = Keyword.get(opts, :scale, 1.0)

    outer_r = 13 * scale
    inner_r = 5 * scale
    size = round(30 * scale)
    gap = round(2 * scale)
    display = hover || rating
    width = 5 * size + 4 * gap

    commands = star_commands(outer_r, inner_r)

    if readonly do
      canvas id,
        width: width,
        height: size,
        alt: "#{rating} out of 5 stars" do
        layer "stars" do
          for i <- 0..4 do
            group x: i * (size + gap) + size / 2, y: size / 2 do
              path(commands, fill: star_color(i < rating, false, theme_progress))
            end
          end
        end
      end
    else
      canvas id,
        width: width,
        height: size,
        alt: "Star rating",
        role: "radiogroup" do
        layer "stars" do
          for i <- 0..4 do
            filled = i < display
            preview = hover != nil and i < hover and i >= rating

            group "star-#{i}",
              x: i * (size + gap) + size / 2,
              y: size / 2,
              on_click: true,
              on_hover: true,
              cursor: "pointer",
              focus_style: %{stroke: %{color: "#3b82f6", width: 2 * scale}},
              show_focus_ring: false,
              a11y: %{
                role: :radio,
                label: "#{i + 1} star#{if i == 0, do: "", else: "s"}",
                selected: rating >= i + 1,
                position_in_set: i + 1,
                size_of_set: 5
              } do
              path(commands, fill: star_color(filled, preview, theme_progress))
            end
          end
        end
      end
    end
  end

  defp star_commands(outer_r, inner_r) do
    points =
      for i <- 0..9 do
        angle = i * :math.pi() / 5 - :math.pi() / 2
        r = if rem(i, 2) == 0, do: outer_r, else: inner_r
        {r * :math.cos(angle), r * :math.sin(angle)}
      end

    [{fx, fy} | rest] = points
    [move_to(fx, fy) | Enum.map(rest, fn {x, y} -> line_to(x, y) end)] ++ [close()]
  end

  defp star_color(true, false, _progress), do: "#f59e0b"
  defp star_color(_, true, _progress), do: "#fcd34d"

  defp star_color(false, false, progress) do
    r = round(209 + (74 - 209) * progress)
    g = round(213 + (74 - 213) * progress)
    b = round(219 + (94 - 219) * progress)
    "#" <> hex(r) <> hex(g) <> hex(b)
  end

  defp hex(n), do: n |> Integer.to_string(16) |> String.pad_leading(2, "0")
end
