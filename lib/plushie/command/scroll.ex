defmodule Plushie.Command.Scroll do
  @moduledoc """
  Scroll commands: absolute, relative, and snap positioning.

  All functions support window-qualified paths (`"window#widget"`).

  ## Example

      def update(model, %WidgetEvent{type: :click, id: "to-top"}) do
        {model, Command.snap_to("main#content", 0.0, 0.0)}
      end
  """

  alias Plushie.Command

  @doc """
  Scroll the widget identified by `widget_id` to `offset`.

  Supports window-qualified paths: `"main#list"`.
  """
  @spec scroll_to(widget_id :: Command.widget_id(), offset :: number()) :: Command.t()
  def scroll_to(widget_id, offset) do
    %Command{type: :scroll_to, payload: Command.targeted_payload(widget_id, %{offset_y: offset})}
  end

  @doc "Snap the scrollable widget to an absolute offset. Supports `\"window#path\"`."
  @spec snap_to(widget_id :: Command.widget_id(), x :: number(), y :: number()) :: Command.t()
  def snap_to(widget_id, x \\ 0.0, y \\ 0.0) do
    %Command{type: :snap_to, payload: Command.targeted_payload(widget_id, %{x: x, y: y})}
  end

  @doc "Snap the scrollable widget to the end of its content. Supports `\"window#path\"`."
  @spec snap_to_end(widget_id :: Command.widget_id()) :: Command.t()
  def snap_to_end(widget_id) do
    %Command{type: :snap_to_end, payload: Command.targeted_payload(widget_id)}
  end

  @doc "Scroll the widget by a relative offset. Supports `\"window#path\"`."
  @spec scroll_by(widget_id :: Command.widget_id(), x :: number(), y :: number()) :: Command.t()
  def scroll_by(widget_id, x \\ 0.0, y \\ 0.0) do
    %Command{type: :scroll_by, payload: Command.targeted_payload(widget_id, %{x: x, y: y})}
  end
end
