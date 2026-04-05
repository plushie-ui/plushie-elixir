defmodule Plushie.Command.Scroll do
  @moduledoc """
  Scroll commands: absolute, relative, and snap positioning.
  """

  alias Plushie.Command

  @doc """
  Scroll the widget identified by `widget_id` to `offset`.

  Supports window-qualified paths: `"main#list"`.
  """
  @spec scroll_to(widget_id :: Command.widget_id(), offset :: term()) :: Command.t()
  def scroll_to(widget_id, offset) do
    {window_id, target} = Command.parse_target(widget_id)
    payload = %{target: target, offset_y: offset}
    payload = if window_id, do: Map.put(payload, :window_id, window_id), else: payload
    %Command{type: :scroll_to, payload: payload}
  end

  @doc "Snap the scrollable widget to an absolute offset. Supports `\"window#path\"`."
  @spec snap_to(widget_id :: Command.widget_id(), x :: float(), y :: float()) :: Command.t()
  def snap_to(widget_id, x \\ 0.0, y \\ 0.0) do
    {window_id, target} = Command.parse_target(widget_id)
    payload = %{target: target, x: x, y: y}
    payload = if window_id, do: Map.put(payload, :window_id, window_id), else: payload
    %Command{type: :snap_to, payload: payload}
  end

  @doc "Snap the scrollable widget to the end of its content. Supports `\"window#path\"`."
  @spec snap_to_end(widget_id :: Command.widget_id()) :: Command.t()
  def snap_to_end(widget_id) do
    {window_id, target} = Command.parse_target(widget_id)
    payload = %{target: target}
    payload = if window_id, do: Map.put(payload, :window_id, window_id), else: payload
    %Command{type: :snap_to_end, payload: payload}
  end

  @doc "Scroll the widget by a relative offset. Supports `\"window#path\"`."
  @spec scroll_by(widget_id :: Command.widget_id(), x :: float(), y :: float()) :: Command.t()
  def scroll_by(widget_id, x \\ 0.0, y \\ 0.0) do
    {window_id, target} = Command.parse_target(widget_id)
    payload = %{target: target, x: x, y: y}
    payload = if window_id, do: Map.put(payload, :window_id, window_id), else: payload
    %Command{type: :scroll_by, payload: payload}
  end
end
