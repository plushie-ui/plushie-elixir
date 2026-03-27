defmodule Plushie.Event.SystemEvent do
  @moduledoc """
  System query responses and platform events.

  Covers responses to system queries (`get_system_info`, `get_system_theme`)
  as well as recurring platform events like animation frames and OS theme
  changes.

  ## Fields

    * `type` - `:system_info`, `:system_theme`, `:animation_frame`,
      `:theme_changed`, `:all_windows_closed`, `:image_list`,
      `:tree_hash`, `:find_focused`, `:diagnostic`, `:announce`, or `:error`
    * `tag` - caller-supplied correlation tag from the originating query
    * `data` - payload; shape depends on event type (e.g. a map of system
      info fields, a theme name string, a frame timestamp, or a renderer
      error payload. Native extension command failures decode to
      `Plushie.Event.ExtensionCommandError` instead.

  ## Pattern matching

      def update(model, %SystemEvent{type: :system_info, data: %{"os" => os}}) do
        %{model | platform: os}
      end

      def update(model, %SystemEvent{type: :theme_changed, data: theme}) do
        %{model | theme: theme}
      end

      def update(model, %SystemEvent{type: :animation_frame, data: ts}) do
        advance_animation(model, ts)
      end
  """

  @type t :: %__MODULE__{
          type:
            :system_info
            | :system_theme
            | :animation_frame
            | :theme_changed
            | :all_windows_closed
            | :image_list
            | :tree_hash
            | :find_focused
            | :announce
            | :diagnostic
            | :error,
          tag: String.t() | nil,
          data: map() | String.t() | number() | nil
        }

  @typedoc "System event delivered by the renderer."
  @type delivered_t :: t()

  @enforce_keys [:type]
  defstruct [:type, :tag, :data]
end
