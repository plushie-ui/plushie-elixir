defmodule Julep.Iced.A11y do
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
  - `live` -- live region semantics: `:off`, `:polite`, or `:assertive`
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
  """

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
    :error_message
  ]

  @type role ::
          :alert
          | :alert_dialog
          | :button
          | :canvas
          | :check_box
          | :combo_box
          | :dialog
          | :document
          | :generic_container
          | :group
          | :heading
          | :image
          | :label
          | :link
          | :list
          | :list_item
          | :menu
          | :menu_bar
          | :menu_item
          | :meter
          | :multiline_text_input
          | :navigation
          | :progress_indicator
          | :radio_button
          | :region
          | :scroll_bar
          | :scroll_view
          | :search
          | :separator
          | :slider
          | :status
          | :switch
          | :tab
          | :tab_list
          | :tab_panel
          | :table
          | :text_input
          | :toolbar
          | :tooltip
          | :tree
          | :tree_item
          | :window

  @type live :: :off | :polite | :assertive

  @type orientation :: :horizontal | :vertical

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
          error_message: String.t() | nil
        }

  @doc """
  Normalizes a struct or bare map into an `A11y` struct.

  Accepts an `A11y` struct (returned as-is) or a bare map with atom keys.
  Unknown keys are silently ignored.

  ## Examples

      iex> Julep.Iced.A11y.cast(%{role: :heading, level: 1})
      %Julep.Iced.A11y{role: :heading, level: 1}

      iex> a11y = %Julep.Iced.A11y{label: "Close"}
      iex> Julep.Iced.A11y.cast(a11y)
      %Julep.Iced.A11y{label: "Close"}
  """
  @spec cast(a11y :: t() | map()) :: t()
  def cast(%__MODULE__{} = a11y), do: a11y

  def cast(map) when is_map(map) do
    %__MODULE__{
      role: map[:role],
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
      mnemonic: validate_mnemonic(map[:mnemonic]),
      toggled: map[:toggled],
      selected: map[:selected],
      value: map[:value],
      orientation: map[:orientation],
      labelled_by: map[:labelled_by],
      described_by: map[:described_by],
      error_message: map[:error_message]
    }
  end

  defp validate_mnemonic(nil), do: nil
  defp validate_mnemonic(<<_::utf8>> = char), do: char

  defp validate_mnemonic(other) do
    raise ArgumentError, "a11y mnemonic must be a single character, got: #{inspect(other)}"
  end
end
