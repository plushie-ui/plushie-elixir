defmodule Plushie.Widget.Meta do
  @moduledoc false

  defmodule Composite do
    @moduledoc false
    @enforce_keys [:module]
    defstruct [:module, :props, :state, :handles_events, :type, :events, :event_specs]

    @type t :: %__MODULE__{
            module: module(),
            props: map() | nil,
            state: map() | nil,
            handles_events: boolean() | nil,
            type: String.t() | nil,
            events: [atom()] | nil,
            event_specs: [map()] | nil
          }
  end

  defmodule Native do
    @moduledoc false
    defstruct [:type, :events, :event_specs]

    @type t :: %__MODULE__{
            type: String.t() | nil,
            events: [atom()] | nil,
            event_specs: [map()] | nil
          }
  end
end
