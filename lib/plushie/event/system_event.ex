defmodule Plushie.Event.SystemEvent do
  @moduledoc """
  System query responses and platform events.

  Covers responses to system queries (`get_system_info`, `get_system_theme`)
  as well as recurring platform events like animation frames and OS theme
  changes.

  ## Fields

    * `type` - `:system_info`, `:system_theme`, `:animation_frame`,
      `:theme_changed`, `:all_windows_closed`, `:image_list`,
      `:tree_hash`, `:find_focused`, `:diagnostic`, `:recovery_failed`,
      `:announce`, or `:error`
    * `tag` - caller-supplied correlation tag from the originating query;
      for diagnostics, the diagnostic code
    * `value` - payload; shape depends on event type
    * `id` - originating widget/canvas ID (diagnostics only)
    * `window_id` - originating window ID (diagnostics only)

  ## Pattern matching

      def update(model, %SystemEvent{type: :system_info, value: %{"os" => os}}) do
        %{model | platform: os}
      end

      def update(model, %SystemEvent{type: :theme_changed, value: theme}) do
        %{model | theme: theme}
      end

      def update(model, %SystemEvent{type: :animation_frame, value: ts}) do
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
            | :recovery_failed
            | :error,
          tag: String.t() | nil,
          value: map() | String.t() | number() | nil,
          id: String.t() | nil,
          window_id: String.t() | nil
        }

  @typedoc "System event delivered by the renderer."
  @type delivered_t :: t()

  @enforce_keys [:type]
  defstruct [:type, :tag, :value, :id, :window_id]
end
