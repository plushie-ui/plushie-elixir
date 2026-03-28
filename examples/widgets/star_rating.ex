defmodule StarRating do
  @moduledoc """
  Canvas-based star rating widget.

  Renders 5 stars as a radio group. Interactive by default (click to
  rate, hover to preview, Tab/arrow to navigate, Enter/Space to select).
  Pass `readonly: true` for a display-only version.

      # Interactive (full size)
      star_rating("my-rating", rating: model.rating, theme_progress: p)

      # Read-only (small, for review display)
      star_rating("review-stars", rating: 4, readonly: true, scale: 0.5)

  Events:
  - `:select` with `%{"value" => n}` when the user clicks a star
  """

  use Plushie.Extension, :widget

  widget(:star_rating)
  prop(:rating, :number)
  prop(:readonly, :boolean, default: false)
  prop(:scale, :number, default: 1.0)
  prop(:theme_progress, :number, default: 0.0)

  event :select, value: :number

  state(hover: nil)

  # -- Event transformation ----------------------------------------------------

  # Click on a star -> emit :select with the 1-based star number.
  @impl Plushie.Extension.CanvasWidget
  def handle_event(%Plushie.Event.WidgetEvent{type: :click, id: "star-" <> n}, _state) do
    {:emit, :select, String.to_integer(n) + 1}
  end

  # Hover enter on a star -> update internal hover state for preview highlight.
  def handle_event(
        %Plushie.Event.WidgetEvent{type: :canvas_element_enter, id: "star-" <> n},
        state
      ) do
    {:update_state, %{state | hover: String.to_integer(n) + 1}}
  end

  # Hover leave -> clear preview highlight.
  def handle_event(%Plushie.Event.WidgetEvent{type: :canvas_element_leave}, state) do
    {:update_state, %{state | hover: nil}}
  end

  # All other events (focus, key, etc.) are consumed -- StarRating only
  # surfaces :select to the parent app.
  def handle_event(_, _state), do: :consumed

  # -- Rendering ---------------------------------------------------------------

  @impl Plushie.Extension.CanvasWidget
  def render(id, props, state) do
    import Plushie.UI

    rating = props.rating || 0
    readonly = props[:readonly] || false
    scale = props[:scale] || 1.0
    theme_progress = props[:theme_progress] || 0.0

    outer_r = 13 * scale
    inner_r = 5 * scale
    size = round(30 * scale)
    gap = round(2 * scale)
    hover = state.hover
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
        role: "radio_group" do
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

  # -- Star geometry -----------------------------------------------------------

  defp star_commands(outer_r, inner_r) do
    points =
      for i <- 0..9 do
        angle = :math.pi() / 2 + i * :math.pi() / 5
        r = if rem(i, 2) == 0, do: outer_r, else: inner_r
        {r * :math.cos(angle), -r * :math.sin(angle)}
      end

    [{x0, y0} | rest] = points

    [
      move_to(x0, y0)
      | Enum.map(rest, fn {x, y} -> line_to(x, y) end)
    ] ++ [close()]
  end

  defp star_color(filled, preview, p) do
    cond do
      preview -> fade({255, 200, 50}, {200, 160, 80}, p)
      filled -> fade({255, 180, 0}, {255, 200, 50}, p)
      true -> fade({224, 224, 224}, {60, 60, 80}, p)
    end
  end

  defp fade({r1, g1, b1}, {r2, g2, b2}, t) do
    r = round(r1 + (r2 - r1) * t)
    g = round(g1 + (g2 - g1) * t)
    b = round(b1 + (b2 - b1) * t)
    "#" <> hex(r) <> hex(g) <> hex(b)
  end

  defp hex(n), do: n |> Integer.to_string(16) |> String.pad_leading(2, "0")
end
