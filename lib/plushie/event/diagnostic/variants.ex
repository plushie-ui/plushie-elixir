defmodule Plushie.Event.Diagnostic.Variants do
  @moduledoc false
  # Struct module definitions for every renderer Diagnostic variant,
  # mirroring the plushie-core `Diagnostic` enum one-to-one.
  #
  # Each struct exposes `from_wire/1` which reads the variant's fields
  # from the raw payload map. Fields are read with defaults of `nil` so
  # a future renderer that drops an optional field does not crash the
  # decoder; fields the wire protocol guarantees are checked explicitly
  # in the variant module.

  @doc false
  # Shared helper: fetch a field from the wire payload, returning the
  # provided default on absence.
  def get(payload, key, default \\ nil) do
    Map.get(payload, key, default)
  end
end

defmodule Plushie.Event.Diagnostic.DuplicateId do
  @moduledoc "A widget ID collided with one already declared within the same window scope."
  @enforce_keys [:id]
  defstruct [:id, :window_id]

  @type t :: %__MODULE__{id: String.t(), window_id: String.t() | nil}

  @doc false
  def from_wire(p) do
    %__MODULE__{id: p["id"], window_id: p["window_id"]}
  end
end

defmodule Plushie.Event.Diagnostic.EmptyId do
  @moduledoc "A view declared a widget with an empty ID where a non-empty one was expected."
  @enforce_keys [:type_name]
  defstruct [:type_name]

  @type t :: %__MODULE__{type_name: String.t()}

  @doc false
  def from_wire(p), do: %__MODULE__{type_name: p["type_name"]}
end

defmodule Plushie.Event.Diagnostic.MultipleTopLevelWindows do
  @moduledoc "The tree holds more than one top-level window child."
  @enforce_keys [:window_ids]
  defstruct [:window_ids]

  @type t :: %__MODULE__{window_ids: [String.t()]}

  @doc false
  def from_wire(p), do: %__MODULE__{window_ids: p["window_ids"] || []}
end

defmodule Plushie.Event.Diagnostic.UnknownWindow do
  @moduledoc "A subscription was declared for a window not present in the tree."
  @enforce_keys [:window_id, :subscription_tag]
  defstruct [:window_id, :subscription_tag]

  @type t :: %__MODULE__{window_id: String.t(), subscription_tag: String.t()}

  @doc false
  def from_wire(p) do
    %__MODULE__{window_id: p["window_id"], subscription_tag: p["subscription_tag"]}
  end
end

defmodule Plushie.Event.Diagnostic.UnrecognizedWidgetPlaceholder do
  @moduledoc "A __widget__ placeholder in the tree had no registered expander."
  @enforce_keys [:id]
  defstruct [:id]

  @type t :: %__MODULE__{id: String.t()}

  @doc false
  def from_wire(p), do: %__MODULE__{id: p["id"]}
end

defmodule Plushie.Event.Diagnostic.TreeDepthExceeded do
  @moduledoc "Tree traversal reached the global depth cap; the subtree was skipped."
  @enforce_keys [:id, :max_depth]
  defstruct [:id, :max_depth]

  @type t :: %__MODULE__{id: String.t(), max_depth: non_neg_integer()}

  @doc false
  def from_wire(p), do: %__MODULE__{id: p["id"], max_depth: p["max_depth"]}
end

defmodule Plushie.Event.Diagnostic.TooManyDuplicates do
  @moduledoc "Duplicate-ID collection stopped at the configured cap."
  @enforce_keys [:limit]
  defstruct [:limit]

  @type t :: %__MODULE__{limit: non_neg_integer()}

  @doc false
  def from_wire(p), do: %__MODULE__{limit: p["limit"]}
end

defmodule Plushie.Event.Diagnostic.WidgetIdInvalid do
  @moduledoc "A user-authored widget ID violated the canonical ID ruleset."
  @enforce_keys [:reason, :type_name, :id, :detail]
  defstruct [:reason, :type_name, :id, :detail]

  @type t :: %__MODULE__{
          reason: String.t(),
          type_name: String.t(),
          id: String.t(),
          detail: String.t()
        }

  @doc false
  def from_wire(p) do
    %__MODULE__{
      reason: p["reason"],
      type_name: p["type_name"],
      id: p["id"],
      detail: p["detail"]
    }
  end
end

defmodule Plushie.Event.Diagnostic.MissingAccessibleName do
  @moduledoc "A widget that requires a screen-reader-announcable name was declared without one."
  @enforce_keys [:type_name, :id]
  defstruct [:type_name, :id]

  @type t :: %__MODULE__{type_name: String.t(), id: String.t()}

  @doc false
  def from_wire(p), do: %__MODULE__{type_name: p["type_name"], id: p["id"]}
end

defmodule Plushie.Event.Diagnostic.A11yRefUnresolved do
  @moduledoc "A cross-widget a11y reference did not resolve to any declared widget."
  @enforce_keys [:id, :key, :value, :is_member]
  defstruct [:id, :key, :value, :is_member]

  @type t :: %__MODULE__{
          id: String.t(),
          key: String.t(),
          value: String.t(),
          is_member: boolean()
        }

  @doc false
  def from_wire(p) do
    %__MODULE__{
      id: p["id"],
      key: p["key"],
      value: p["value"],
      is_member: p["is_member"] || false
    }
  end
end

defmodule Plushie.Event.Diagnostic.PropRangeExceeded do
  @moduledoc "A numeric prop was outside its declared range and was clamped."
  @enforce_keys [:id, :type_name, :prop, :raw, :clamped, :non_finite]
  defstruct [:id, :type_name, :prop, :raw, :clamped, :non_finite]

  @type t :: %__MODULE__{
          id: String.t(),
          type_name: String.t(),
          prop: String.t(),
          raw: float() | integer(),
          clamped: float() | integer(),
          non_finite: boolean()
        }

  @doc false
  def from_wire(p) do
    %__MODULE__{
      id: p["id"],
      type_name: p["type_name"],
      prop: p["prop"],
      raw: p["raw"],
      clamped: p["clamped"],
      non_finite: p["non_finite"] || false
    }
  end
end

defmodule Plushie.Event.Diagnostic.PropTypeMismatch do
  @moduledoc "A prop value had an unexpected JSON type."
  @enforce_keys [:id, :type_name, :prop, :value_debug, :expected_debug]
  defstruct [:id, :type_name, :prop, :value_debug, :expected_debug]

  @type t :: %__MODULE__{
          id: String.t(),
          type_name: String.t(),
          prop: String.t(),
          value_debug: String.t(),
          expected_debug: String.t()
        }

  @doc false
  def from_wire(p) do
    %__MODULE__{
      id: p["id"],
      type_name: p["type_name"],
      prop: p["prop"],
      value_debug: p["value_debug"],
      expected_debug: p["expected_debug"]
    }
  end
end

defmodule Plushie.Event.Diagnostic.PropUnknown do
  @moduledoc "A widget carried a prop name not in its declared schema."
  @enforce_keys [:id, :type_name, :prop, :known_debug]
  defstruct [:id, :type_name, :prop, :known_debug]

  @type t :: %__MODULE__{
          id: String.t(),
          type_name: String.t(),
          prop: String.t(),
          known_debug: String.t()
        }

  @doc false
  def from_wire(p) do
    %__MODULE__{
      id: p["id"],
      type_name: p["type_name"],
      prop: p["prop"],
      known_debug: p["known_debug"]
    }
  end
end

defmodule Plushie.Event.Diagnostic.ContentLengthExceeded do
  @moduledoc "A text-like content prop exceeded its per-widget byte cap and was truncated."
  @enforce_keys [:id, :field, :actual, :cap, :truncated]
  defstruct [:id, :field, :actual, :cap, :truncated]

  @type t :: %__MODULE__{
          id: String.t(),
          field: String.t(),
          actual: non_neg_integer(),
          cap: non_neg_integer(),
          truncated: non_neg_integer()
        }

  @doc false
  def from_wire(p) do
    %__MODULE__{
      id: p["id"],
      field: p["field"],
      actual: p["actual"],
      cap: p["cap"],
      truncated: p["truncated"]
    }
  end
end

defmodule Plushie.Event.Diagnostic.FontCacheCapExceeded do
  @moduledoc "The leaked font-family-name cache reached its entry cap."
  @enforce_keys [:max]
  defstruct [:max]

  @type t :: %__MODULE__{max: non_neg_integer()}

  @doc false
  def from_wire(p), do: %__MODULE__{max: p["max"]}
end

defmodule Plushie.Event.Diagnostic.FontCapExceeded do
  @moduledoc "Inline fonts declared in Settings exceeded the process-wide cap."
  @enforce_keys [:max, :requested, :granted, :dropped]
  defstruct [:max, :requested, :granted, :dropped]

  @type t :: %__MODULE__{
          max: non_neg_integer(),
          requested: non_neg_integer(),
          granted: non_neg_integer(),
          dropped: non_neg_integer()
        }

  @doc false
  def from_wire(p) do
    %__MODULE__{
      max: p["max"],
      requested: p["requested"],
      granted: p["granted"],
      dropped: p["dropped"]
    }
  end
end

defmodule Plushie.Event.Diagnostic.FontFamilyNotFound do
  @moduledoc "A font family from default_font or its fallback chain did not resolve."
  @enforce_keys [:family]
  defstruct [:family]

  @type t :: %__MODULE__{family: String.t()}

  @doc false
  def from_wire(p), do: %__MODULE__{family: p["family"]}
end

defmodule Plushie.Event.Diagnostic.InvalidSettings do
  @moduledoc "The Settings payload failed typed deny_unknown_fields validation."
  @enforce_keys [:detail]
  defstruct [:detail]

  @type t :: %__MODULE__{detail: String.t()}

  @doc false
  def from_wire(p), do: %__MODULE__{detail: p["detail"]}
end

defmodule Plushie.Event.Diagnostic.RequiredWidgetsMissing do
  @moduledoc "The Settings handshake declared native widget names the renderer does not know about."
  @enforce_keys [:missing]
  defstruct [:missing]

  @type t :: %__MODULE__{missing: [String.t()]}

  @doc false
  def from_wire(p), do: %__MODULE__{missing: p["missing"] || []}
end

defmodule Plushie.Event.Diagnostic.WidgetPanic do
  @moduledoc "A non-trusted widget panicked inside the registry's catch_unwind firewall."
  @enforce_keys [:id, :type_name, :label]
  defstruct [:id, :type_name, :label]

  @type t :: %__MODULE__{id: String.t(), type_name: String.t(), label: String.t()}

  @doc false
  def from_wire(p) do
    %__MODULE__{id: p["id"], type_name: p["type_name"], label: p["label"]}
  end
end

defmodule Plushie.Event.Diagnostic.SvgParseError do
  @moduledoc "SVG decode returned a parse error."
  @enforce_keys [:id, :source, :detail]
  defstruct [:id, :source, :detail]

  @type t :: %__MODULE__{id: String.t(), source: String.t(), detail: String.t()}

  @doc false
  def from_wire(p) do
    %__MODULE__{id: p["id"], source: p["source"], detail: p["detail"]}
  end
end

defmodule Plushie.Event.Diagnostic.SvgDecodeTimeout do
  @moduledoc "SVG decode exceeded its wall-clock budget."
  @enforce_keys [:id, :source, :deadline_debug]
  defstruct [:id, :source, :deadline_debug]

  @type t :: %__MODULE__{id: String.t(), source: String.t(), deadline_debug: String.t()}

  @doc false
  def from_wire(p) do
    %__MODULE__{id: p["id"], source: p["source"], deadline_debug: p["deadline_debug"]}
  end
end

defmodule Plushie.Event.Diagnostic.DashCacheCapExceeded do
  @moduledoc "The leaked dash-segment cache reached its entry cap."
  @enforce_keys [:max]
  defstruct [:max]

  @type t :: %__MODULE__{max: non_neg_integer()}

  @doc false
  def from_wire(p), do: %__MODULE__{max: p["max"]}
end

defmodule Plushie.Event.Diagnostic.DashSegmentsCapExceeded do
  @moduledoc "A canvas dash pattern exceeded the per-pattern segment limit."
  @enforce_keys [:max]
  defstruct [:max]

  @type t :: %__MODULE__{max: non_neg_integer()}

  @doc false
  def from_wire(p), do: %__MODULE__{max: p["max"]}
end

defmodule Plushie.Event.Diagnostic.EmitterCoalesceCapExceeded do
  @moduledoc "The renderer-lib event coalesce map hit its cap and was force-flushed."
  @enforce_keys [:cap]
  defstruct [:cap]

  @type t :: %__MODULE__{cap: non_neg_integer()}

  @doc false
  def from_wire(p), do: %__MODULE__{cap: p["cap"]}
end

defmodule Plushie.Event.Diagnostic.WidgetIdTypeCollision do
  @moduledoc "A composite widget ID was registered against two different widget types."
  @enforce_keys [:id, :existing_type, :incoming_type]
  defstruct [:id, :existing_type, :incoming_type]

  @type t :: %__MODULE__{
          id: String.t(),
          existing_type: String.t(),
          incoming_type: String.t()
        }

  @doc false
  def from_wire(p) do
    %__MODULE__{
      id: p["id"],
      existing_type: p["existing_type"],
      incoming_type: p["incoming_type"]
    }
  end
end

defmodule Plushie.Event.Diagnostic.ViewPanicked do
  @moduledoc "The view function panicked and was caught by the runtime's safety net."
  @enforce_keys [:consecutive, :message]
  defstruct [:consecutive, :message]

  @type t :: %__MODULE__{consecutive: non_neg_integer(), message: String.t()}

  @doc false
  def from_wire(p) do
    %__MODULE__{consecutive: p["consecutive"], message: p["message"]}
  end
end

defmodule Plushie.Event.Diagnostic.UpdatePanicked do
  @moduledoc """
  The update function panicked and was caught by the runtime. The
  model is reverted to the last-good snapshot so the app keeps
  running; the consecutive counter is shared with `ViewPanicked` so
  the frozen-UI overlay surfaces after enough total panics across
  either callback.
  """
  @enforce_keys [:consecutive, :message]
  defstruct [:consecutive, :message]

  @type t :: %__MODULE__{consecutive: non_neg_integer(), message: String.t()}

  @doc false
  def from_wire(p) do
    %__MODULE__{consecutive: p["consecutive"], message: p["message"]}
  end
end

defmodule Plushie.Event.Diagnostic.UnknownMessageType do
  @moduledoc "A wire message carried a `type` field the SDK does not recognise."
  @enforce_keys [:msg_type]
  defstruct [:msg_type]

  @type t :: %__MODULE__{msg_type: String.t()}

  @doc false
  def from_wire(p), do: %__MODULE__{msg_type: p["msg_type"]}
end

defmodule Plushie.Event.Diagnostic.UnknownPatchOp do
  @moduledoc "A patch operation name was not recognised by the renderer."
  @enforce_keys [:op, :payload]
  defstruct [:op, :payload]

  @type t :: %__MODULE__{op: String.t(), payload: term()}

  @doc false
  def from_wire(p), do: %__MODULE__{op: p["op"], payload: p["payload"]}
end

defmodule Plushie.Event.Diagnostic.DispatchLoopExceeded do
  @moduledoc """
  The runtime's command dispatch chain exceeded the configured depth
  limit, indicating an `update` loop that keeps returning a command
  whose delivered event produces another command.
  """
  @enforce_keys [:depth, :limit]
  defstruct [:depth, :limit]

  @type t :: %__MODULE__{depth: non_neg_integer(), limit: non_neg_integer()}

  @doc false
  def from_wire(p), do: %__MODULE__{depth: p["depth"], limit: p["limit"]}
end

defmodule Plushie.Event.Diagnostic.BufferOverflow do
  @moduledoc """
  A single wire message exceeded the protocol's 64 MiB per-message
  size cap.
  """
  @enforce_keys [:size, :limit]
  defstruct [:size, :limit]

  @type t :: %__MODULE__{size: non_neg_integer(), limit: non_neg_integer()}

  @doc false
  def from_wire(p), do: %__MODULE__{size: p["size"], limit: p["limit"]}
end

defmodule Plushie.Event.Diagnostic.WireInputError do
  @moduledoc "A renderer input frame was readable but could not be decoded."
  @enforce_keys [:detail]
  defstruct [:detail]

  @type t :: %__MODULE__{detail: String.t()}

  @doc false
  def from_wire(p), do: %__MODULE__{detail: p["detail"]}
end

defmodule Plushie.Event.Diagnostic.AnimationDescriptorInvalid do
  @moduledoc "A renderer-side animation descriptor could not be parsed."
  @enforce_keys [:id, :prop]
  defstruct [:id, :prop]

  @type t :: %__MODULE__{id: String.t(), prop: String.t()}

  @doc false
  def from_wire(p), do: %__MODULE__{id: p["id"], prop: p["prop"]}
end

defmodule Plushie.Event.Diagnostic.RendererRuntimeError do
  @moduledoc "The renderer event loop returned a terminal runtime error after startup."
  @enforce_keys [:detail]
  defstruct [:detail]

  @type t :: %__MODULE__{detail: String.t()}

  @doc false
  def from_wire(p), do: %__MODULE__{detail: p["detail"]}
end
