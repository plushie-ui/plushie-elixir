defmodule Julep.Iced.A11y do
  @moduledoc """
  Accessibility annotation type for widget nodes.

  When attached to a widget via the `a11y` prop, these attributes override the
  auto-inferred accessibility semantics on the renderer side. The renderer
  automatically derives roles and labels from widget types and props (e.g. a
  button's label becomes the accessible name), so most widgets need no explicit
  `a11y` annotation. Use this for cases where auto-inference is insufficient.

  ## Fields

  - `role` -- overrides the inferred accesskit role (e.g. `"heading"`, `"alert"`)
  - `label` -- accessible name announced by screen readers
  - `description` -- longer description (maps to accesskit description)
  - `live` -- live region semantics: `:off`, `:polite`, or `:assertive`
  - `hidden` -- if true, node is excluded from the accessibility tree
  - `expanded` -- expanded/collapsed state for disclosure widgets
  - `required` -- marks a form field as required
  - `level` -- heading level (1-6)
  """

  @type live :: :off | :polite | :assertive

  @type t :: %{
          optional(:role) => String.t(),
          optional(:label) => String.t(),
          optional(:description) => String.t(),
          optional(:live) => live(),
          optional(:hidden) => boolean(),
          optional(:expanded) => boolean(),
          optional(:required) => boolean(),
          optional(:level) => pos_integer()
        }
end
