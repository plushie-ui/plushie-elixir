defmodule Julep.Event.System do
  @moduledoc "System query responses and platform events."

  @type t :: %__MODULE__{
          type: :system_info | :system_theme | :animation_frame | :theme_changed,
          tag: String.t() | nil,
          data: term()
        }

  defstruct [:type, :tag, :data]
end
