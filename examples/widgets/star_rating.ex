defmodule StarRating do
  @moduledoc """
  Canvas-based star rating widget.

  Renders 5 interactive stars. Click to rate, hover to preview.

      StarRating.render("my-rating", model.rating,
        hover: model.hover_star, dark: model.dark?)

  Events: `canvas_shape_click` with shape_id `"star-0"` through `"star-4"`.
  Hover: `canvas_shape_enter`/`canvas_shape_leave` with the same shape_ids.
  """

  import Plushie.Canvas.Shape, only: [move_to: 2, line_to: 2, close: 0]

  @outer_r 12
  @inner_r 5
  @size 28
  @gap 8

  @doc "Renders a star rating canvas widget."
  def render(id, rating, opts \\ []) do
    import Plushie.UI

    hover = Keyword.get(opts, :hover)
    dark = Keyword.get(opts, :dark, false)
    display = hover || rating
    width = 5 * @size + 4 * @gap

    canvas id, width: width, height: @size do
      layer "stars" do
        for i <- 0..4 do
          cx = i * (@size + @gap) + @size / 2
          cy = @size / 2
          filled = i < display
          preview = hover != nil and i < hover and i >= rating

          group x: cx, y: cy do
            interactive "star-#{i}" do
              on_click
              on_hover
              cursor("pointer")
            end

            path(star_commands(), fill: star_color(filled, preview, dark))
          end
        end
      end
    end
  end

  defp star_commands do
    points =
      for i <- 0..9 do
        angle = i * :math.pi() / 5 - :math.pi() / 2
        r = if rem(i, 2) == 0, do: @outer_r, else: @inner_r
        {r * :math.cos(angle), r * :math.sin(angle)}
      end

    [{fx, fy} | rest] = points
    [move_to(fx, fy) | Enum.map(rest, fn {x, y} -> line_to(x, y) end)] ++ [close()]
  end

  defp star_color(true, false, _dark), do: "#f59e0b"
  defp star_color(_, true, _dark), do: "#fcd34d"
  defp star_color(false, false, false), do: "#d1d5db"
  defp star_color(false, false, true), do: "#4a4a5e"
end
