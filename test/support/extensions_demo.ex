if Code.ensure_loaded?(ToddySparkline) and Code.ensure_loaded?(ToddyHexView) and
     Code.ensure_loaded?(ToddyCodeView) and Code.ensure_loaded?(ToddyPlot) and
     Code.ensure_loaded?(ToddyTimeline) do
  defmodule Toddy.Examples.ExtensionsDemo do
    @moduledoc """
    Demo app using all 5 extension widgets simultaneously.

    Verifies coexistence: no type name collisions, correct config routing,
    correct command routing, and independent rendering.

    Only compiled when extension deps are available (dev/test).
    """

    use Toddy.App

    alias Toddy.Event.Timer
    alias Toddy.Event.Widget
    import Toddy.UI

    @impl true
    def init(_flags) do
      %{
        tick: 0,
        paused: false,
        hex_text: "Hello, Toddy!",
        code: "fn main() {\n    println!(\"Hello!\");\n}",
        language: "rust",
        selected_interval: nil
      }
    end

    @impl true
    def update(model, message) do
      case message do
        %Timer{tag: :tick} ->
          if model.paused do
            model
          else
            tick = model.tick + 1
            value = :math.sin(tick * 0.1) * 50 + 50
            {%{model | tick: tick}, [ToddySparkline.push("spark", value)]}
          end

        %Widget{type: :click, id: "timeline"} ->
          %{model | selected_interval: "clicked"}

        _ ->
          model
      end
    end

    @impl true
    def view(model) do
      window "extensions-demo", title: "Extensions Demo" do
        column padding: 10, spacing: 10 do
          text("demo_title", "All 5 Extension Widgets", size: 24)

          # Row 1: Sparkline + Hex View
          row spacing: 20 do
            column spacing: 5 do
              text("sparkline_label", "Sparkline", size: 16)

              ToddySparkline.new("spark")
              |> ToddySparkline.color("#4FC3F7")
              |> ToddySparkline.width(200)
              |> ToddySparkline.height(60)
            end

            column spacing: 5 do
              text("hex_label", "Hex View", size: 16)

              ToddyHexView.new("hex",
                data: model.hex_text,
                bytes_per_row: 8,
                height: 80
              )
            end
          end

          # Row 2: Code View
          column spacing: 5 do
            text("code_label", "Code View", size: 16)

            ToddyCodeView.new("code",
              code: model.code,
              language: model.language,
              line_numbers: true,
              height: 120
            )
          end

          # Row 3: Plot
          column spacing: 5 do
            text("plot_label", "Plot", size: 16)

            ToddyPlot.new("plot",
              series: [
                %{
                  name: "sine",
                  data: for(i <- 0..20, do: {i, :math.sin(i * 0.3) * 50 + 50}),
                  color: "#4FC3F7"
                },
                %{
                  name: "cosine",
                  data: for(i <- 0..20, do: {i, :math.cos(i * 0.3) * 50 + 50}),
                  color: "#FF7043"
                }
              ],
              width: :fill,
              height: 150
            )
          end

          # Row 4: Timeline
          column spacing: 5 do
            text("timeline_label", "Timeline", size: 16)

            ToddyTimeline.new("timeline",
              intervals: [
                ToddyTimeline.interval("req-1", "GET /api", 0, 150,
                  lane: 0,
                  color: "#4FC3F7"
                ),
                ToddyTimeline.interval("db-1", "SELECT users", 20, 80,
                  lane: 1,
                  color: "#66BB6A"
                ),
                ToddyTimeline.interval("job-1", "SendEmail", 100, 300,
                  lane: 2,
                  color: "#FF7043"
                )
              ],
              width: :fill,
              height: 120
            )
          end
        end
      end
    end

    @impl true
    def subscribe(model) do
      if model.paused do
        []
      else
        [Toddy.Subscription.every(100, :tick)]
      end
    end
  end
end
