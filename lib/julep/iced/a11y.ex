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
  """

  defstruct [:role, :label, :description, :live, :hidden, :expanded,
             :required, :level]

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

  @type t :: %__MODULE__{
          role: role() | nil,
          label: String.t() | nil,
          description: String.t() | nil,
          live: live() | nil,
          hidden: boolean() | nil,
          expanded: boolean() | nil,
          required: boolean() | nil,
          level: pos_integer() | nil
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
      level: map[:level]
    }
  end
end
