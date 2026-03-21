defmodule Plushie.Type.A11y do
  @moduledoc """
  Accessibility annotation type for widget nodes.

  When attached to a widget via the `a11y` prop, these attributes override the
  auto-inferred accessibility semantics on the renderer side. The renderer
  automatically derives roles and labels from widget types and props (e.g. a
  button's label becomes the accessible name), so most widgets need no explicit
  `a11y` annotation. Use this for cases where auto-inference is insufficient.

  Use `cast/1` to normalize a bare map into an `A11y` struct. Bare maps with
  atom keys are accepted for convenience.

  ## Fields

  - `role` -- overrides the inferred accesskit role (e.g. `:heading`, `:alert`)
  - `label` -- accessible name announced by screen readers
  - `description` -- longer description (maps to accesskit description)
  - `live` -- live region semantics: `:polite` or `:assertive`
  - `hidden` -- if true, node is excluded from the accessibility tree
  - `expanded` -- expanded/collapsed state for disclosure widgets
  - `required` -- marks a form field as required
  - `level` -- heading level (1-6)
  - `busy` -- loading/processing state
  - `invalid` -- form validation failure
  - `modal` -- dialog is modal
  - `read_only` -- can be read but not edited
  - `mnemonic` -- Alt+letter keyboard shortcut (single character)
  - `toggled` -- toggled/checked state (for custom toggle widgets)
  - `selected` -- selected state (for custom selectable widgets)
  - `value` -- current value as a string (for custom value-displaying widgets)
  - `orientation` -- `:horizontal` or `:vertical` (for custom oriented widgets)
  - `labelled_by` -- ID of the widget that labels this one
  - `described_by` -- ID of the widget that describes this one
  - `error_message` -- ID of the widget showing the error message for this one
  - `disabled` -- override disabled state for AT
  - `position_in_set` -- 1-based position within a set (lists, radio groups, tabs)
  - `size_of_set` -- total items in the set
  - `has_popup` -- popup type: `"listbox"`, `"menu"`, `"dialog"`, `"tree"`, `"grid"`
  """

  @behaviour Plushie.DSL.Buildable

  @known_keys ~w(role label description live hidden expanded required level busy invalid modal read_only mnemonic toggled selected value orientation labelled_by described_by error_message disabled position_in_set size_of_set has_popup)a

  defstruct [
    :role,
    :label,
    :description,
    :live,
    :hidden,
    :expanded,
    :required,
    :level,
    :busy,
    :invalid,
    :modal,
    :read_only,
    :mnemonic,
    :toggled,
    :selected,
    :value,
    :orientation,
    :labelled_by,
    :described_by,
    :error_message,
    :disabled,
    :position_in_set,
    :size_of_set,
    :has_popup
  ]

  @roles ~w(
    alert alert_dialog button canvas check_box combo_box dialog document
    generic_container group heading image label link list list_item
    menu menu_bar menu_item meter multiline_text_input navigation
    progress_indicator radio_button region scroll_bar scroll_view
    search separator slider static_text status switch tab tab_list
    tab_panel table text_input toolbar tooltip tree tree_item window
  )a

  @live_values ~w(polite assertive)a

  @orientations ~w(horizontal vertical)a

  @type role :: unquote(Enum.reduce(@roles, &{:|, [], [&1, &2]}))

  @type live :: :polite | :assertive

  @type orientation :: :horizontal | :vertical

  @has_popup_values ~w(listbox menu dialog tree grid)

  @type has_popup :: String.t() | nil

  @type t :: %__MODULE__{
          role: role() | nil,
          label: String.t() | nil,
          description: String.t() | nil,
          live: live() | nil,
          hidden: boolean() | nil,
          expanded: boolean() | nil,
          required: boolean() | nil,
          level: pos_integer() | nil,
          busy: boolean() | nil,
          invalid: boolean() | nil,
          modal: boolean() | nil,
          read_only: boolean() | nil,
          mnemonic: String.t() | nil,
          toggled: boolean() | nil,
          selected: boolean() | nil,
          value: String.t() | nil,
          orientation: orientation() | nil,
          labelled_by: String.t() | nil,
          described_by: String.t() | nil,
          error_message: String.t() | nil,
          disabled: boolean() | nil,
          position_in_set: non_neg_integer() | nil,
          size_of_set: non_neg_integer() | nil,
          has_popup: has_popup()
        }

  @doc """
  Normalizes a struct or bare map into an `A11y` struct.

  Accepts an `A11y` struct (returned as-is) or a bare map with atom keys.
  Unknown keys are silently ignored.

  ## Examples

      iex> Plushie.Type.A11y.cast(%{role: :heading, level: 1})
      %Plushie.Type.A11y{role: :heading, level: 1}

      iex> a11y = %Plushie.Type.A11y{label: "Close"}
      iex> Plushie.Type.A11y.cast(a11y)
      %Plushie.Type.A11y{label: "Close"}
  """
  @spec cast(a11y :: t() | map()) :: t()
  def cast(%__MODULE__{} = a11y), do: a11y

  def cast(map) when is_map(map) do
    %__MODULE__{
      role: validate_role(map[:role]),
      label: map[:label],
      description: map[:description],
      live: validate_live(map[:live]),
      hidden: map[:hidden],
      expanded: map[:expanded],
      required: map[:required],
      level: validate_level(map[:level]),
      busy: map[:busy],
      invalid: map[:invalid],
      modal: map[:modal],
      read_only: map[:read_only],
      mnemonic: validate_mnemonic(map[:mnemonic]),
      toggled: map[:toggled],
      selected: map[:selected],
      value: map[:value],
      orientation: validate_orientation(map[:orientation]),
      labelled_by: map[:labelled_by],
      described_by: map[:described_by],
      error_message: map[:error_message],
      disabled: map[:disabled],
      position_in_set: validate_non_neg_integer(map[:position_in_set]),
      size_of_set: validate_non_neg_integer(map[:size_of_set]),
      has_popup: validate_has_popup(map[:has_popup])
    }
  end

  defp validate_role(nil), do: nil
  defp validate_role(role) when role in @roles, do: role

  defp validate_live(nil), do: nil
  defp validate_live(live) when live in @live_values, do: live

  defp validate_orientation(nil), do: nil
  defp validate_orientation(o) when o in @orientations, do: o

  defp validate_level(nil), do: nil
  defp validate_level(n) when is_integer(n) and n >= 1 and n <= 6, do: n

  defp validate_mnemonic(nil), do: nil
  defp validate_mnemonic(<<_::utf8>> = char), do: char

  defp validate_non_neg_integer(nil), do: nil
  defp validate_non_neg_integer(n) when is_integer(n) and n >= 0, do: n

  defp validate_has_popup(nil), do: nil
  defp validate_has_popup(v) when v in @has_popup_values, do: v

  @impl Plushie.DSL.Buildable
  def __field_keys__, do: @known_keys

  @impl Plushie.DSL.Buildable
  def __field_types__, do: %{}

  @doc "Constructs an `A11y` struct from a keyword list."
  @impl Plushie.DSL.Buildable
  @spec from_opts(opts :: keyword()) :: t()
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown a11y field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    cast(Map.new(opts))
  end
end

defimpl Plushie.Encode, for: Plushie.Type.A11y do
  def encode(%Plushie.Type.A11y{} = a11y) do
    a11y
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, Plushie.Encode.encode(v)} end)
  end
end
