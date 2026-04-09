defmodule Plushie.UI.WidgetSet do
  @moduledoc """
  Macro for creating widget set modules that override built-in widget macros.

  A widget set is a module that re-exports all of `Plushie.UI` but replaces
  specific widget macros with alternatives. This enables widget packs,
  custom themes, and per-app widget customization without manual import
  juggling.

  ## Usage

  Define a widget set module:

      defmodule MyApp.MaterialUI do
        use Plushie.UI.WidgetSet,
          override: [
            button: MyApp.Widgets.MaterialButton,
            text_input: MyApp.Widgets.MaterialTextInput
          ]
      end

  Use it in view functions:

      defmodule MyApp do
        use Plushie.App

        def view(model) do
          import MyApp.MaterialUI

          window "main", title: "My App" do
            button("save", "Save")       # uses MaterialButton
            text("greeting", "Hello")    # uses built-in (not overridden)
          end
        end
      end

  ## How it works

  The macro generates a module that:
  1. Imports all of `Plushie.UI` except the overridden widget macros
  2. Imports the override modules, bringing their macros into scope
  3. Re-exports everything so consumers get a single import

  Override modules must export macros with the same names and compatible
  arities as the built-in widgets they replace. The easiest way to create
  an override module is with `use Plushie.Widget`:

      defmodule MyApp.Widgets.MaterialButton do
        use Plushie.Widget

        widget :button do
          field :label, :string
          field :rounded, :boolean, default: true
          # ... material-specific fields
        end

        def view(id, props) do
          import Plushie.UI
          button(id, props.label, style: :primary, padding: 12)
        end
      end
  """

  defmacro __using__(opts) do
    overrides = Keyword.get(opts, :override, [])

    unless is_list(overrides) and Enum.all?(overrides, &match?({_, _}, &1)) do
      raise ArgumentError,
            "Plushie.UI.WidgetSet :override must be a keyword list of " <>
              "{widget_name, module} pairs, got: #{inspect(overrides)}"
    end

    # Build the except list by introspecting each override module's macros.
    # We exclude all arities of each overridden widget name from Plushie.UI.
    except_pairs =
      for {widget_name, _mod} <- overrides do
        # Get all arities that Plushie.UI exports for this macro name.
        # The generated macros typically have arities 1, 2, 3 (some have more).
        plushie_ui_macros = Plushie.UI.__info__(:macros)

        matching =
          for {name, arity} <- plushie_ui_macros,
              name == widget_name,
              do: {name, arity}

        if matching == [] do
          raise ArgumentError,
                "Plushie.UI.WidgetSet override: #{inspect(widget_name)} is not a " <>
                  "macro exported by Plushie.UI"
        end

        matching
      end
      |> List.flatten()

    # Generate the import statements.
    override_imports =
      for {_widget_name, mod} <- overrides do
        quote do
          import unquote(mod)
        end
      end

    quote do
      defmacro __using__(_opts) do
        except = unquote(Macro.escape(except_pairs))

        override_imports =
          unquote(Macro.escape(override_imports))

        quote do
          import Plushie.UI, except: unquote(except)
          unquote_splicing(override_imports)
        end
      end
    end
  end
end
