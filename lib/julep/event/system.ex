defmodule Julep.Event.System do
  @moduledoc """
  System query responses and platform events.

  Covers responses to system queries (`get_system_info`, `get_system_theme`)
  as well as recurring platform events like animation frames and OS theme
  changes.

  ## Fields

    * `type` - `:system_info`, `:system_theme`, `:animation_frame`,
      `:theme_changed`, or `:all_windows_closed`
    * `tag` - caller-supplied correlation tag from the originating query
    * `data` - payload; shape depends on event type (e.g. a map of system
      info fields, a theme name string, or a frame timestamp)

  ## Pattern matching

      def update(model, %System{type: :system_info, data: %{"os" => os}}) do
        %{model | platform: os}
      end

      def update(model, %System{type: :theme_changed, data: theme}) do
        %{model | theme: theme}
      end

      def update(model, %System{type: :animation_frame, data: ts}) do
        advance_animation(model, ts)
      end
  """

  @type t :: %__MODULE__{
          type:
            :system_info
            | :system_theme
            | :animation_frame
            | :theme_changed
            | :all_windows_closed,
          tag: String.t() | nil,
          data: term()
        }

  @enforce_keys [:type]
  defstruct [:type, :tag, :data]
end
