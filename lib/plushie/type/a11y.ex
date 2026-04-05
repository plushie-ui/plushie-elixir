defmodule Plushie.Type.A11y do
  @moduledoc """
  Accessibility annotation type for widget nodes.

  When attached to a widget via the `a11y` prop, these attributes override the
  auto-inferred accessibility semantics on the renderer side. The renderer
  automatically derives roles and labels from widget types and props (e.g. a
  button's label becomes the accessible name), so most widgets need no explicit
  `a11y` annotation. Use this for cases where auto-inference is insufficient.

  ## Construction

  Builder chain (like Border, Shadow, Font):

      A11y.new()
      |> A11y.role(:heading)
      |> A11y.level(1)
      |> A11y.label("Page title")

  Bare map via `cast/1` (convenience for inline props):

      Button.new("btn", "Go", a11y: %{label: "Go forward"})

  DSL do-block via `from_opts/1`:

      button "btn", "Go" do
        a11y do
          label "Go forward"
        end
      end

  ## Override semantics

  Most fields are optional overrides. When nil (the default), the
  renderer uses its auto-inferred value. When set, the SDK value wins.

  Some widgets auto-manage certain fields based on their interaction
  state. For example, sliders set `busy: true` during drag so that
  assistive technology suppresses rapid value announcements and
  announces only the final value on release. Setting `busy` explicitly
  from the SDK overrides this auto-detected state.

  ## Busy and live regions

  `busy` maps to WAI-ARIA `aria-busy`. When true on a node (or a
  parent of a live region), assistive technology suppresses
  announcements until busy clears, then announces the final state.

  Widgets that own continuous interactions (sliders) set this
  automatically. For app-managed live regions that reflect another
  widget's state (e.g. a text display showing a color value during
  canvas drag), set `busy` explicitly based on the interaction state:

      text("hex", hex_value,
        a11y: %{live: :polite, busy: model.drag != :none}
      )

  ## Fields

  - `role` -- overrides the inferred accesskit role (e.g. `:heading`, `:alert`)
  - `label` -- accessible name announced by screen readers
  - `description` -- longer description (maps to accesskit description)
  - `live` -- live region semantics: `:polite` or `:assertive`
  - `hidden` -- if true, node is excluded from the accessibility tree
  - `expanded` -- expanded/collapsed state for disclosure widgets
  - `required` -- marks a form field as required
  - `level` -- heading level (1-6)
  - `busy` -- suppresses AT announcements until cleared (auto-managed
    by sliders during drag; set explicitly for custom continuous
    interactions)
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

  @canonical_roles ~w(
    alert alert_dialog button canvas check_box combo_box dialog document
    generic_container group heading image label link list list_item
    menu menu_bar menu_item meter multiline_text_input navigation
    progress_indicator radio_button radio_group region scroll_bar scroll_view
    search separator slider static_text status switch tab tab_list
    tab_panel table table_row table_cell column_header text_input toolbar
    tooltip tree tree_item window
  )a

  @role_aliases %{
    cell: :table_cell,
    checkbox: :check_box,
    container: :generic_container,
    generic: :generic_container,
    progress_bar: :progress_indicator,
    radio: :radio_button,
    row: :table_row,
    text_editor: :multiline_text_input
  }

  @role_alias_keys ~w(cell checkbox container generic progress_bar radio row text_editor)a
  @accepted_roles @canonical_roles ++ @role_alias_keys

  @type role :: unquote(Enum.reduce(@canonical_roles, &{:|, [], [&1, &2]}))
  @type role_input :: role() | unquote(Enum.reduce(@role_alias_keys, &{:|, [], [&1, &2]}))

  @type live :: :polite | :assertive

  @type orientation :: :horizontal | :vertical

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

  # -- Construction -------------------------------------------------------------

  @doc "Creates an empty A11y struct with all fields nil."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Normalizes a struct, map, or keyword list into an `A11y` struct.

  Accepts an `A11y` struct, a bare map with atom keys, or a keyword list.
  Unknown keys are silently ignored. Role aliases like `:checkbox` and
  `:radio` are normalized to their canonical forms.

  ## Examples

      iex> Plushie.Type.A11y.cast(%{role: :heading, level: 1})
      {:ok, %Plushie.Type.A11y{role: :heading, level: 1}}

      iex> Plushie.Type.A11y.cast(role: :heading, level: 1)
      {:ok, %Plushie.Type.A11y{role: :heading, level: 1}}

      iex> a11y = %Plushie.Type.A11y{label: "Close"}
      iex> Plushie.Type.A11y.cast(a11y)
      {:ok, %Plushie.Type.A11y{label: "Close"}}
  """
  @behaviour Plushie.Type

  @impl Plushie.Type
  @spec cast(a11y :: t() | map() | keyword()) :: {:ok, t()} | :error
  def cast(%__MODULE__{} = a11y), do: {:ok, normalize!(a11y)}
  def cast(kw) when is_list(kw), do: cast(Map.new(kw))

  def cast(map) when is_map(map) do
    if map[:mnemonic], do: validate_mnemonic!(map[:mnemonic])

    {:ok,
     %__MODULE__{
       role: normalize_optional_role!(map[:role]),
       label: map[:label],
       description: map[:description],
       live: map[:live],
       hidden: map[:hidden],
       expanded: map[:expanded],
       required: map[:required],
       level: map[:level],
       busy: map[:busy],
       invalid: map[:invalid],
       modal: map[:modal],
       read_only: map[:read_only],
       mnemonic: map[:mnemonic],
       toggled: map[:toggled],
       selected: map[:selected],
       value: map[:value],
       orientation: map[:orientation],
       labelled_by: map[:labelled_by],
       described_by: map[:described_by],
       error_message: map[:error_message],
       disabled: map[:disabled],
       position_in_set: map[:position_in_set],
       size_of_set: map[:size_of_set],
       has_popup: map[:has_popup]
     }}
  rescue
    ArgumentError -> :error
  end

  def cast(_), do: :error

  # -- Setter functions --------------------------------------------------------

  @doc """
  Sets the accessibility role.

  Supported aliases normalize to canonical roles:
  `:checkbox` -> `:check_box`, `:radio` -> `:radio_button`,
  `:text_editor` -> `:multiline_text_input`, `:progress_bar` -> `:progress_indicator`,
  `:generic` / `:container` -> `:generic_container`, `:row` -> `:table_row`,
  and `:cell` -> `:table_cell`.
  """
  @spec role(a11y :: t(), role :: role_input()) :: t()
  def role(%__MODULE__{} = a, role) when is_atom(role), do: %{a | role: normalize_role!(role)}

  @doc "Sets the accessible label (name announced by screen readers)."
  @spec label(a11y :: t(), label :: String.t()) :: t()
  def label(%__MODULE__{} = a, label) when is_binary(label), do: %{a | label: label}

  @doc "Sets the longer accessible description."
  @spec description(a11y :: t(), description :: String.t()) :: t()
  def description(%__MODULE__{} = a, desc) when is_binary(desc), do: %{a | description: desc}

  @doc "Sets the live region semantics (`:polite` or `:assertive`)."
  @spec live(a11y :: t(), live :: live()) :: t()
  def live(%__MODULE__{} = a, live) when is_atom(live), do: %{a | live: live}

  @doc "Sets whether the node is hidden from the accessibility tree."
  @spec hidden(a11y :: t(), hidden :: boolean()) :: t()
  def hidden(%__MODULE__{} = a, hidden) when is_boolean(hidden), do: %{a | hidden: hidden}

  @doc "Sets the expanded/collapsed state."
  @spec expanded(a11y :: t(), expanded :: boolean()) :: t()
  def expanded(%__MODULE__{} = a, expanded) when is_boolean(expanded),
    do: %{a | expanded: expanded}

  @doc "Marks a form field as required."
  @spec required(a11y :: t(), required :: boolean()) :: t()
  def required(%__MODULE__{} = a, required) when is_boolean(required),
    do: %{a | required: required}

  @doc "Sets the heading level (1-6)."
  @spec level(a11y :: t(), level :: pos_integer()) :: t()
  def level(%__MODULE__{} = a, level) when is_integer(level) and level >= 1 and level <= 6,
    do: %{a | level: level}

  @doc """
  Suppresses AT announcements until cleared.

  Sliders set this automatically during drag. For custom continuous
  interactions, set explicitly to prevent rapid-fire announcements
  on live regions.
  """
  @spec busy(a11y :: t(), busy :: boolean()) :: t()
  def busy(%__MODULE__{} = a, busy) when is_boolean(busy), do: %{a | busy: busy}

  @doc "Sets the form validation failure state."
  @spec invalid(a11y :: t(), invalid :: boolean()) :: t()
  def invalid(%__MODULE__{} = a, invalid) when is_boolean(invalid), do: %{a | invalid: invalid}

  @doc "Sets whether a dialog is modal."
  @spec modal(a11y :: t(), modal :: boolean()) :: t()
  def modal(%__MODULE__{} = a, modal) when is_boolean(modal), do: %{a | modal: modal}

  @doc "Sets the read-only state."
  @spec read_only(a11y :: t(), read_only :: boolean()) :: t()
  def read_only(%__MODULE__{} = a, read_only) when is_boolean(read_only),
    do: %{a | read_only: read_only}

  @doc "Sets the Alt+letter keyboard shortcut (single character)."
  @spec mnemonic(a11y :: t(), mnemonic :: String.t()) :: t()
  def mnemonic(%__MODULE__{} = a, char) when is_binary(char) do
    validate_mnemonic!(char)
    %{a | mnemonic: char}
  end

  @doc "Sets the toggled/checked state."
  @spec toggled(a11y :: t(), toggled :: boolean()) :: t()
  def toggled(%__MODULE__{} = a, toggled) when is_boolean(toggled), do: %{a | toggled: toggled}

  @doc "Sets the selected state."
  @spec selected(a11y :: t(), selected :: boolean()) :: t()
  def selected(%__MODULE__{} = a, selected) when is_boolean(selected),
    do: %{a | selected: selected}

  @doc "Sets the current value as a string."
  @spec value(a11y :: t(), value :: String.t()) :: t()
  def value(%__MODULE__{} = a, value) when is_binary(value), do: %{a | value: value}

  @doc "Sets the orientation (`:horizontal` or `:vertical`)."
  @spec orientation(a11y :: t(), orientation :: orientation()) :: t()
  def orientation(%__MODULE__{} = a, orientation) when is_atom(orientation),
    do: %{a | orientation: orientation}

  @doc "Sets the ID of the widget that labels this one."
  @spec labelled_by(a11y :: t(), id :: String.t()) :: t()
  def labelled_by(%__MODULE__{} = a, id) when is_binary(id), do: %{a | labelled_by: id}

  @doc "Sets the ID of the widget that describes this one."
  @spec described_by(a11y :: t(), id :: String.t()) :: t()
  def described_by(%__MODULE__{} = a, id) when is_binary(id), do: %{a | described_by: id}

  @doc "Sets the ID of the widget showing the error message."
  @spec error_message(a11y :: t(), id :: String.t() | nil) :: t()
  def error_message(%__MODULE__{} = a, id) when is_binary(id) or is_nil(id),
    do: %{a | error_message: id}

  @doc "Overrides the disabled state for assistive technology."
  @spec disabled(a11y :: t(), disabled :: boolean()) :: t()
  def disabled(%__MODULE__{} = a, disabled) when is_boolean(disabled),
    do: %{a | disabled: disabled}

  @doc "Sets the 1-based position within a set."
  @spec position_in_set(a11y :: t(), pos :: non_neg_integer()) :: t()
  def position_in_set(%__MODULE__{} = a, pos) when is_integer(pos) and pos >= 0,
    do: %{a | position_in_set: pos}

  @doc "Sets the total number of items in the set."
  @spec size_of_set(a11y :: t(), size :: non_neg_integer()) :: t()
  def size_of_set(%__MODULE__{} = a, size) when is_integer(size) and size >= 0,
    do: %{a | size_of_set: size}

  @doc ~S[Sets the popup type (`"listbox"`, `"menu"`, `"dialog"`, `"tree"`, `"grid"`).]
  @spec has_popup(a11y :: t(), popup :: String.t()) :: t()
  def has_popup(%__MODULE__{} = a, popup) when is_binary(popup), do: %{a | has_popup: popup}

  # -- Buildable ---------------------------------------------------------------

  def __field_keys__, do: @known_keys

  def __field_types__, do: %{}

  @doc false
  @spec normalize!(t()) :: t()
  def normalize!(%__MODULE__{} = a11y) do
    %{a11y | role: normalize_optional_role!(a11y.role)}
  end

  @doc false
  @spec accepted_roles() :: [role_input()]
  def accepted_roles, do: @accepted_roles

  @doc "Constructs an `A11y` struct from a keyword list."
  @spec from_opts(opts :: keyword()) :: t()
  def from_opts(opts) when is_list(opts) do
    for {key, _} <- opts, key not in @known_keys do
      raise ArgumentError,
            "unknown a11y field #{inspect(key)}. Valid fields: #{inspect(@known_keys)}"
    end

    # Filter nils so that `label: if(cond, do: "Name")` doesn't crash
    # the guard when cond is false -- nil means "don't set" (struct default).
    opts
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.reduce(new(), fn
      {:role, v}, acc -> role(acc, v)
      {:label, v}, acc -> label(acc, v)
      {:description, v}, acc -> description(acc, v)
      {:live, v}, acc -> live(acc, v)
      {:hidden, v}, acc -> hidden(acc, v)
      {:expanded, v}, acc -> expanded(acc, v)
      {:required, v}, acc -> required(acc, v)
      {:level, v}, acc -> level(acc, v)
      {:busy, v}, acc -> busy(acc, v)
      {:invalid, v}, acc -> invalid(acc, v)
      {:modal, v}, acc -> modal(acc, v)
      {:read_only, v}, acc -> read_only(acc, v)
      {:mnemonic, v}, acc -> mnemonic(acc, v)
      {:toggled, v}, acc -> toggled(acc, v)
      {:selected, v}, acc -> selected(acc, v)
      {:value, v}, acc -> value(acc, v)
      {:orientation, v}, acc -> orientation(acc, v)
      {:labelled_by, v}, acc -> labelled_by(acc, v)
      {:described_by, v}, acc -> described_by(acc, v)
      {:error_message, v}, acc -> error_message(acc, v)
      {:disabled, v}, acc -> disabled(acc, v)
      {:position_in_set, v}, acc -> position_in_set(acc, v)
      {:size_of_set, v}, acc -> size_of_set(acc, v)
      {:has_popup, v}, acc -> has_popup(acc, v)
    end)
  end

  defp normalize_optional_role!(nil), do: nil
  defp normalize_optional_role!(role) when is_atom(role), do: normalize_role!(role)

  defp normalize_optional_role!(role) do
    raise ArgumentError,
          "invalid a11y role #{inspect(role)}. Expected an atom, got: #{inspect(role)}"
  end

  defp normalize_role!(role) do
    cond do
      role in @canonical_roles -> role
      canonical = @role_aliases[role] -> canonical
      true -> raise ArgumentError, unknown_role_message(role)
    end
  end

  defp unknown_role_message(role) do
    "unknown a11y role #{inspect(role)}. Supported roles: #{inspect(@accepted_roles)}"
  end

  defp validate_mnemonic!(char) when is_binary(char) do
    if String.length(char) != 1 do
      raise ArgumentError,
            "mnemonic must be a single character, got: #{inspect(char)}"
    end
  end

  # -- Plushie.Type callbacks --------------------------------------------------

  @doc false
  @impl Plushie.Type
  def typespec do
    quote do: %Plushie.Type.A11y{} | map() | keyword()
  end

  @doc false
  @impl Plushie.Type
  def guard(var) do
    quote do: is_map(unquote(var)) or is_list(unquote(var))
  end
end

defimpl Plushie.Encode, for: Plushie.Type.A11y do
  def encode(%Plushie.Type.A11y{} = a11y) do
    a11y
    |> Plushie.Type.A11y.normalize!()
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, Plushie.Encode.encode(v)} end)
  end
end
