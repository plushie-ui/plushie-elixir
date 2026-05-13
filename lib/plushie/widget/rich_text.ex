defmodule Plushie.Widget.RichText do
  @moduledoc """
  Rich text display with individually styled spans.

  Spans are typed via `Plushie.Widget.RichText.Span`. Construct them
  with `span/1` plus chained setters or pass a plain map for ad-hoc
  cases. Typed spans are encoded automatically; plain maps fall
  through unchanged.

      alias Plushie.Widget.RichText.Span

      rich_text "status",
        spans: [
          Span.new("Build ") |> Span.color("#000000"),
          Span.new("ok") |> Span.color("#22aa22") |> Span.underline(true)
        ]

  ## Accessibility

  Screen readers see individual spans but cannot infer the overall
  meaning of the composed text. Set `a11y: %{label: "..."}` with a
  plain-text summary so assistive technology can announce the full
  content in one pass:

      rich_text "status", spans: spans,
        a11y: %{label: "Build succeeded in 3.2 seconds"}

  For content that updates dynamically, combine `label` with a live
  region annotation so changes are announced automatically:

      rich_text "output", spans: spans,
        a11y: %{label: summary_text, live: :polite}
  """

  use Plushie.Widget

  @a11y_defaults %{role: :label}

  widget :rich_text do
    field :spans, {:list, :map},
      doc: "List of span descriptors. Use `Plushie.Widget.RichText.Span` or plain maps."

    field :width, Plushie.Type.Length, doc: "Widget width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Widget height. Default: shrink."
    field :size, :float, doc: "Default font size for all spans."
    field :font, Plushie.Type.Font, doc: "Default font for all spans."
    field :color, Plushie.Type.Color, doc: "Default text color for all spans."

    field :line_height, Plushie.Type.LineHeight,
      doc: "Line height. Number is relative; map for explicit control."

    field :wrapping, Plushie.Type.Wrapping, doc: "Text wrapping mode."

    field :ellipsis, Plushie.Type.Ellipsis,
      doc: "Text ellipsis mode: `:none`, `:start`, `:middle`, `:end`."

    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end

  event :link_click, value: :string, doc: "Emitted when a span link is clicked."
end
