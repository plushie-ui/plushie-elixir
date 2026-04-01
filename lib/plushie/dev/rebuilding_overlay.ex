defmodule Plushie.Dev.RebuildingOverlay do
  @moduledoc false

  # Builds and injects a dev-mode overlay bar into the UI tree.
  #
  # The overlay is a slim, semi-transparent bar at the top of each window
  # showing rebuild status. It has a collapsible drawer for detailed output.
  #
  # All overlay widget IDs use the "__plushie_dev__/" prefix so the
  # Runtime can intercept their events before they reach app.update/2.

  @prefix "__plushie_dev__"
  @dismiss_ms 1500

  @type status :: :building | :succeeded | :failed

  @type t :: %__MODULE__{
          status: status(),
          detail: String.t(),
          expanded: boolean()
        }

  defstruct status: :building,
            detail: "",
            expanded: false

  @doc "Auto-dismiss delay in milliseconds."
  @spec dismiss_ms() :: pos_integer()
  def dismiss_ms, do: @dismiss_ms

  @doc "Returns the display message for a given status."
  @spec status_message(status()) :: String.t()
  def status_message(:building), do: "Rebuilding..."
  def status_message(:succeeded), do: "Rebuild succeeded."
  def status_message(:failed), do: "Rebuild failed."

  @doc "Returns true if the given event ID belongs to the overlay."
  @spec overlay_event?(id :: String.t()) :: boolean()
  def overlay_event?(id) when is_binary(id), do: String.starts_with?(id, @prefix <> "/")
  def overlay_event?(_), do: false

  @doc "Extracts the action from an overlay event ID."
  @spec action(id :: String.t()) :: String.t()
  def action(id), do: String.replace_prefix(id, @prefix <> "/", "")

  # -- Action handling --------------------------------------------------------

  @doc """
  Handles an overlay user action (toggle, dismiss).

  Returns:
  - `{:updated, overlay}` -- overlay state changed, re-render needed
  - `:dismissed` -- overlay should be removed
  - `:noop` -- no change
  """
  @spec handle_action(action :: String.t(), overlay :: t()) ::
          {:updated, t()} | :dismissed | :noop
  def handle_action("toggle", overlay) do
    {:updated, %{overlay | expanded: not overlay.expanded}}
  end

  def handle_action("dismiss", _overlay), do: :dismissed
  def handle_action(_action, _overlay), do: :noop

  # -- Tree injection ---------------------------------------------------------

  @doc "Injects the overlay into a tree, or returns the tree unchanged if overlay is nil."
  @spec maybe_inject(tree :: map(), overlay :: t() | nil) :: map()
  def maybe_inject(tree, nil), do: tree
  def maybe_inject(tree, overlay), do: inject(tree, overlay)

  @spec inject(tree :: map(), overlay :: t()) :: map()
  defp inject(tree, overlay) do
    overlay_node = build_overlay(overlay)

    if has_window_nodes?(tree) do
      inject_into_windows(tree, overlay_node)
    else
      wrap_root(tree, overlay_node)
    end
  end

  defp has_window_nodes?(%{type: "window"}), do: true

  defp has_window_nodes?(%{children: children}) when is_list(children) do
    Enum.any?(children, &has_window_nodes?/1)
  end

  defp has_window_nodes?(_), do: false

  defp inject_into_windows(%{type: "window"} = node, overlay_node) do
    wrapped_children =
      case node.children do
        [content | rest] ->
          [wrap_root(content, overlay_node) | rest]

        [] ->
          [overlay_node]
      end

    %{node | children: wrapped_children}
  end

  defp inject_into_windows(%{children: children} = node, overlay_node) when is_list(children) do
    %{node | children: Enum.map(children, &inject_into_windows(&1, overlay_node))}
  end

  defp inject_into_windows(node, _overlay_node), do: node

  defp wrap_root(content, overlay_node) do
    %{
      id: "#{@prefix}/stack",
      type: "stack",
      props: %{width: :fill, height: :fill},
      children: [content, overlay_node]
    }
  end

  # -- Overlay node building --------------------------------------------------

  defp build_overlay(overlay) do
    bar = build_bar(overlay)
    drawer = if overlay.expanded, do: [build_drawer(overlay)], else: []

    %{
      id: "#{@prefix}/anchor",
      type: "container",
      props: %{width: :fill, align_y: :top},
      children: [
        %{
          id: "#{@prefix}/column",
          type: "column",
          props: %{
            padding: %{top: 8, right: 8, bottom: 0, left: 8},
            width: :shrink,
            max_width: 600
          },
          children: [bar | drawer]
        }
      ]
    }
  end

  defp build_bar(overlay) do
    toggle_label = if overlay.expanded, do: "^", else: "v"

    status_icon =
      case overlay.status do
        :building -> "..."
        :succeeded -> "ok"
        :failed -> "!!"
      end

    text_color = bar_text_color(overlay.status)
    message = status_message(overlay.status)

    children = [
      %{
        id: "#{@prefix}/toggle",
        type: "button",
        props: %{label: toggle_label, style: "text", padding: 0, width: 20},
        children: []
      },
      %{
        id: "#{@prefix}/icon",
        type: "text",
        props: %{content: "[#{status_icon}]", color: text_color, size: 12},
        children: []
      },
      %{
        id: "#{@prefix}/status",
        type: "text",
        props: %{content: message, color: text_color, size: 12},
        children: []
      }
    ]

    children =
      if overlay.status == :failed do
        children ++
          [
            %{
              id: "#{@prefix}/dismiss",
              type: "button",
              props: %{label: "x", style: "text", padding: 0, width: 20},
              children: []
            }
          ]
      else
        children
      end

    %{
      id: "#{@prefix}/bar",
      type: "container",
      props: %{
        background: bar_background(overlay.status),
        padding: %{top: 6, right: 12, bottom: 6, left: 8},
        border: %{radius: 6}
      },
      children: [
        %{
          id: "#{@prefix}/bar_row",
          type: "row",
          props: %{spacing: 6, align_y: :center},
          children: children
        }
      ]
    }
  end

  defp build_drawer(overlay) do
    content =
      if overlay.detail == "" do
        "(waiting for output)"
      else
        overlay.detail
      end

    %{
      id: "#{@prefix}/drawer",
      type: "container",
      props: %{
        background: "rgba(0, 0, 0, 0.85)",
        padding: %{top: 6, right: 12, bottom: 8, left: 12},
        max_height: 300,
        border: %{radius: 6}
      },
      children: [
        %{
          id: "#{@prefix}/scrollable",
          type: "scrollable",
          props: %{height: :shrink},
          children: [
            %{
              id: "#{@prefix}/output",
              type: "text",
              props: %{
                content: content,
                color: "#cccccc",
                size: 11,
                font: %{family: "monospace"}
              },
              children: []
            }
          ]
        }
      ]
    }
  end

  defp bar_background(:failed), do: "rgba(180, 40, 40, 0.85)"
  defp bar_background(_), do: "rgba(0, 0, 0, 0.7)"

  defp bar_text_color(:failed), do: "#ffaaaa"
  defp bar_text_color(:succeeded), do: "#aaffaa"
  defp bar_text_color(_), do: "#ffffff"
end
