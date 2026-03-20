defmodule Toddy.UI do
  @moduledoc """
  Ergonomic builder layer for Toddy UI trees.

  Import this module in your `view/1` function to get concise widget builder
  syntax with optional `do` block sugar for children.

  ## Usage

      def view(model) do
        import Toddy.UI

        window "main", title: "Counter" do
          column do
            text("Count: \#{model.count}")
            row do
              button("increment", "+")
              button("decrement", "-")
            end
          end
        end
      end

  ## Node shape

  Every builder produces:

      %{id: string, type: string, props: %{}, children: []}

  Props use atom keys internally; string keys are used only at the wire encoding
  boundary. Reserved opts keys (`:children`, `:id`, `:do`) are not treated as props.

  ## Two equivalent forms

  The `do` block is sugar that compiles to the explicit `:children` form:

      column(padding: 8, children: [text("hello")])

      column padding: 8 do
        text("hello")
      end

  Inside a `do` block:
  - `for` comprehensions work (they return lists; one level is flattened)
  - `if` without `else` works (returns nil; nils are filtered out)

  ## Auto-IDs

  **WARNING: Auto-generated IDs are unstable.** Layout and display widgets
  that do not receive an explicit `:id` option generate one from the call
  site line number: `"auto:ModuleName:42"`. These IDs change whenever you
  refactor code, add/remove lines above the call, or use conditional
  rendering (`if`/`case`) that moves the call to a different branch.

  When an ID changes between renders, the renderer treats it as a
  removal + insertion, **losing all widget-local state** (scroll position,
  text cursor, focus, editor content).

  **Always supply explicit `:id` opts for stateful widgets:**
  `text_editor`, `combo_box`, `pane_grid`, `scrollable`, `text_input`.

  Auto-IDs are fine for purely visual widgets like `text`, `row`, `column`
  where state loss is invisible.

  ## Formatter

  Toddy exports formatter settings that keep layout blocks paren-free so
  they read like declarative markup. Add `:toddy` to `import_deps` in
  your `.formatter.exs`:

      # .formatter.exs
      [
        inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
        import_deps: [:toddy]
      ]

  Layout blocks stay paren-free; leaf widgets keep parens for clarity:

      column padding: 8 do
        text("count", "Count: \#{model.count}", size: 24)
        button("inc", "+1")
      end

  ## Tree query

  `find/2` is re-exported from `Toddy.Tree` for convenience:

      Toddy.UI.find(tree, "my_button")
  """

  # ---------------------------------------------------------------------------
  # Core build helpers (public -- macro-generated code calls these at runtime)
  # ---------------------------------------------------------------------------

  @doc false
  @spec __build_container__(
          widget_mod :: module(),
          id :: String.t() | nil,
          opts :: keyword(),
          children :: [Toddy.Widget.ui_node()],
          auto_id :: String.t() | nil
        ) :: Toddy.Widget.ui_node()
  def __build_container__(widget_mod, id, opts, children, auto_id) do
    resolved_id = id || Keyword.get(opts, :id) || auto_id

    resolved_children =
      if children != [] do
        children
      else
        Keyword.get(opts, :children, [])
      end

    clean_opts = clean_opts(opts)

    widget = widget_mod.new(resolved_id, clean_opts)

    widget =
      if resolved_children != [] do
        widget_mod.extend(widget, resolved_children)
      else
        widget
      end

    widget_mod.build(widget)
  end

  # Kept for external callers. Internal macros use compile_auto_id/2 to
  # compute the string at compile time and inject a literal, avoiding
  # runtime Module.split + Enum.join on every render.
  @doc false
  @spec __auto_id__(mod :: module() | nil, line :: non_neg_integer()) :: String.t()
  def __auto_id__(nil, line), do: "auto:nomodule:#{line}"

  def __auto_id__(mod, line) do
    mod_str = mod |> Module.split() |> Enum.join(".")
    "auto:#{mod_str}:#{line}"
  end

  # Compile-time auto ID computation. Called inside defmacro bodies where
  # __CALLER__.module and __CALLER__.line are known at compile time.
  # The result is injected as a string literal in the generated code.
  @doc false
  defp compile_auto_id(nil, line), do: "auto:nomodule:#{line}"

  defp compile_auto_id(mod, line) do
    mod_str = mod |> Module.split() |> Enum.join(".")
    "auto:#{mod_str}:#{line}"
  end

  # ---------------------------------------------------------------------------
  # Positional argument validation
  # ---------------------------------------------------------------------------

  # Several widget functions accept required values as positional args followed
  # by an optional keyword list.  It is easy to accidentally pass the value as
  # a keyword (e.g. `text_input("id", value: v)` instead of
  # `text_input("id", v)`).  Elixir merges the keyword into the preceding
  # argument silently, so we guard against it here.  A FunctionClauseError
  # showing the keyword list in the args is far clearer than a cryptic
  # Msgpax.Packer error three layers deep.

  @doc false
  defguard is_keyword(v)
           when is_list(v) and v != [] and is_tuple(hd(v)) and tuple_size(hd(v)) == 2 and
                  is_atom(elem(hd(v), 0))

  # ---------------------------------------------------------------------------
  # Layout widgets
  # ---------------------------------------------------------------------------

  # -- window(id, opts) -------------------------------------------------------
  # All forms are macros so there is no def/defmacro arity conflict.
  #
  #   window("main")
  #   window("main", title: "App")
  #   window "main" do ... end
  #   window "main", title: "App" do ... end

  @doc """
  Top-level window container.

  ## Arguments

  - `id`   -- stable string identifier for this window
  - `opts` -- keyword list; common option: `:title`

  ## Example

      window "main", title: "My App" do
        column do
          text("Hello")
        end
      end
  """
  defmacro window(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Window,
            unquote(id),
            [],
            children,
            nil
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Window,
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro window(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Window,
        unquote(id),
        unquote(opts),
        children,
        nil
      )
    end
  end

  # -- column(opts) -----------------------------------------------------------
  # All forms are macros so we always have __CALLER__ for auto-ID.
  #
  #   column()
  #   column(padding: 8)
  #   column do ... end
  #   column padding: 8 do ... end

  @doc """
  Vertical flex layout.

  ## Options

  - `:spacing` -- gap between children
  - `:padding` -- padding around children
  - `:width` / `:height` -- `:fill`, `:shrink`, or number
  - `:align_x` -- `:start`, `:center`, `:end`
  - `:id` -- explicit ID (otherwise auto-generated from call site)
  - `:children` -- child nodes (function-form shorthand)

  ## Example

      column spacing: 8 do
        text("Hello")
        text("World")
      end
  """
  defmacro column(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Column,
            nil,
            [],
            children,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Column,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro column(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Column,
        nil,
        unquote(opts),
        children,
        unquote(compile_auto_id(caller_mod, caller_line))
      )
    end
  end

  # -- row(opts) --------------------------------------------------------------

  @doc """
  Horizontal flex layout.

  ## Options

  Same as `column/1`.

  ## Example

      row spacing: 4 do
        button("yes", "Yes")
        button("no", "No")
      end
  """
  defmacro row(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Row,
            nil,
            [],
            children,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Row,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro row(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Row,
        nil,
        unquote(opts),
        children,
        unquote(compile_auto_id(caller_mod, caller_line))
      )
    end
  end

  # -- container(id, opts) ----------------------------------------------------

  @doc """
  Generic box with alignment and padding.

  ## Example

      container "hero", padding: 16 do
        text("Welcome")
      end
  """
  defmacro container(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Container, unquote(id), [], children, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Container,
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro container(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Container,
        unquote(id),
        unquote(opts),
        children,
        nil
      )
    end
  end

  # -- overlay(id, opts) ------------------------------------------------------

  @doc """
  Overlay container. First child is the anchor, second is the overlay content.

  ## Options

  - `:position` -- `:below`, `:above`, `:left`, `:right`
  - `:gap` -- space between anchor and overlay in pixels
  - `:offset_x` -- horizontal offset in pixels
  - `:offset_y` -- vertical offset in pixels

  ## Example

      overlay "popup", position: :below, gap: 4 do
        button("anchor", "Click me")
        container "dropdown" do
          text("dropdown_text", "Dropdown content")
        end
      end
  """
  defmacro overlay(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Overlay, unquote(id), [], children, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Overlay, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro overlay(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Overlay,
        unquote(id),
        unquote(opts),
        children,
        nil
      )
    end
  end

  # -- scrollable(id, opts) ---------------------------------------------------

  @doc """
  Scrollable region.

  ## Example

      scrollable "feed" do
        for item <- items do
          text(item.title)
        end
      end
  """
  defmacro scrollable(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Scrollable, unquote(id), [], children, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Scrollable,
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro scrollable(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Scrollable,
        unquote(id),
        unquote(opts),
        children,
        nil
      )
    end
  end

  # -- stack(opts) ------------------------------------------------------------

  @doc """
  Z-axis stacking layout (overlays).

  ## Example

      stack do
        image("bg", "/path/to/bg.png")
        container "overlay", padding: 16 do
          text("Overlaid text")
        end
      end
  """
  defmacro stack(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Stack,
            nil,
            [],
            children,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Stack,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro stack(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Stack,
        nil,
        unquote(opts),
        children,
        unquote(compile_auto_id(caller_mod, caller_line))
      )
    end
  end

  # -- grid(opts) -------------------------------------------------------------

  @doc """
  Grid layout.

  ## Options

  - `:column_count` -- number of columns
  - `:column_width` -- width of each column
  - `:row_height` -- height of each row
  - `:spacing` -- gap between cells
  - `:padding` -- padding around grid
  - `:width` / `:height` -- dimensions
  - `:id` -- explicit ID (otherwise auto-generated from call site)

  ## Example

      grid column_count: 3, spacing: 8 do
        for item <- items do
          text(item.name)
        end
      end
  """
  defmacro grid(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Grid,
            nil,
            [],
            children,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Grid,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro grid(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Grid,
        nil,
        unquote(opts),
        children,
        unquote(compile_auto_id(caller_mod, caller_line))
      )
    end
  end

  # -- keyed_column(opts) -----------------------------------------------------

  @doc """
  Keyed column for efficient list diffing.

  ## Options

  Same as `column/1`.

  ## Example

      keyed_column spacing: 8 do
        for item <- items do
          text(item.id, item.name)
        end
      end
  """
  defmacro keyed_column(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.KeyedColumn,
            nil,
            [],
            children,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.KeyedColumn,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro keyed_column(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.KeyedColumn,
        nil,
        unquote(opts),
        children,
        unquote(compile_auto_id(caller_mod, caller_line))
      )
    end
  end

  # -- responsive(opts) -------------------------------------------------------

  @doc """
  Responsive layout that adapts to available size.

  ## Options

  - `:width` / `:height` -- dimensions
  - `:id` -- explicit ID (otherwise auto-generated from call site)

  ## Example

      responsive do
        column do
          text("Adapts to size")
        end
      end
  """
  defmacro responsive(opts_or_block \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    case opts_or_block do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Responsive,
            nil,
            [],
            children,
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Responsive,
            nil,
            unquote(opts),
            [],
            unquote(compile_auto_id(caller_mod, caller_line))
          )
        end
    end
  end

  @doc false
  defmacro responsive(opts, do: block) do
    exprs = block_to_exprs(block)
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Responsive,
        nil,
        unquote(opts),
        children,
        unquote(compile_auto_id(caller_mod, caller_line))
      )
    end
  end

  # -- pin(id, opts) ----------------------------------------------------------

  @doc """
  Pin layout for absolute positioning.

  ## Example

      pin "overlay" do
        text("Pinned content")
      end
  """
  defmacro pin(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Pin, unquote(id), [], children, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Pin, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro pin(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Toddy.UI.__build_container__(Toddy.Widget.Pin, unquote(id), unquote(opts), children, nil)
    end
  end

  # -- float_widget(id, opts) -------------------------------------------------

  @doc """
  Floating overlay layout.

  ## Example

      float_widget "popup" do
        text("Floating content")
      end
  """
  defmacro float_widget(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Float, unquote(id), [], children, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Float, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro float_widget(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Toddy.UI.__build_container__(Toddy.Widget.Float, unquote(id), unquote(opts), children, nil)
    end
  end

  # -- mouse_area(id, opts) ---------------------------------------------------

  @doc """
  Mouse area for capturing mouse events on children.

  ## Options

  - `:on_press`, `:on_release`, `:on_right_press`, `:on_middle_press`
  - `:on_enter`, `:on_exit`

  ## Example

      mouse_area "clickable" do
        text("Click me")
      end
  """
  defmacro mouse_area(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.MouseArea, unquote(id), [], children, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.MouseArea,
            unquote(id),
            unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro mouse_area(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.MouseArea,
        unquote(id),
        unquote(opts),
        children,
        nil
      )
    end
  end

  # -- sensor(id, opts) -------------------------------------------------------

  @doc """
  Sensor for detecting layout changes on children.

  ## Options

  - `:on_resize`, `:on_appear`

  ## Example

      sensor "tracked" do
        text("Monitored content")
      end
  """
  defmacro sensor(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Sensor, unquote(id), [], children, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Sensor, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro sensor(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Toddy.UI.__build_container__(Toddy.Widget.Sensor, unquote(id), unquote(opts), children, nil)
    end
  end

  # -- themer(id, opts) -------------------------------------------------------

  @doc """
  Per-subtree theme override.

  ## Options

  - `:theme` -- theme name string or custom palette map

  ## Example

      themer "dark_section", theme: "Dark" do
        column do
          text("This subtree uses the dark theme")
        end
      end
  """
  defmacro themer(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Themer, unquote(id), [], children, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Themer, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro themer(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Toddy.UI.__build_container__(Toddy.Widget.Themer, unquote(id), unquote(opts), children, nil)
    end
  end

  # -- space(opts) ------------------------------------------------------------

  @doc """
  Flexible spacer. No children.

  ## Options

  - `:width` -- `:fill`, `:shrink`, or number
  - `:height` -- `:fill`, `:shrink`, or number
  """
  defmacro space(opts \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      Toddy.UI.__build_container__(
        Toddy.Widget.Space,
        nil,
        unquote(opts),
        [],
        unquote(compile_auto_id(caller_mod, caller_line))
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Input widgets (require explicit id; no do-block form needed)
  # ---------------------------------------------------------------------------

  @doc """
  Clickable button.

  Emits `%Widget{type: :click, id: id}` when clicked.

  ## Example

      button("save", "Save", style: :primary)
  """
  @spec button(id :: String.t(), label :: String.t(), opts :: keyword()) :: Toddy.Widget.ui_node()
  def button(id, label, opts \\ []) do
    Toddy.Widget.Button.new(id, label, clean_opts(opts)) |> Toddy.Widget.Button.build()
  end

  @doc """
  Single-line text input.

  Emits `%Widget{type: :input, id: id, value: value}` on change and `%Widget{type: :submit, id: id, value: value}` on Enter.

  ## Example

      text_input("name", model.name, placeholder: "Your name")
  """
  @spec text_input(id :: String.t(), value :: String.t(), opts :: keyword()) ::
          Toddy.Widget.ui_node()
  def text_input(id, value, opts \\ [])

  def text_input(id, value, opts) when not is_keyword(value) do
    Toddy.Widget.TextInput.new(id, value, clean_opts(opts)) |> Toddy.Widget.TextInput.build()
  end

  @doc """
  Boolean checkbox toggle.

  Emits `%Widget{type: :toggle, id: id, value: boolean}` when toggled.

  ## Example

      checkbox("agree", model.agreed, label: "I agree")
  """
  @spec checkbox(id :: String.t(), checked :: boolean(), opts :: keyword()) ::
          Toddy.Widget.ui_node()
  def checkbox(id, checked, opts \\ [])

  def checkbox(id, checked, opts) when not is_keyword(checked) do
    clean = clean_opts(opts)
    {label, remaining} = Keyword.pop(clean, :label, "")
    Toddy.Widget.Checkbox.new(id, label, checked, remaining) |> Toddy.Widget.Checkbox.build()
  end

  # ---------------------------------------------------------------------------
  # Display widgets
  # ---------------------------------------------------------------------------

  @doc """
  Text label.

  ## Forms

  - `text(content)` -- auto-generated ID (sugar for quick labels)
  - `text(id, content)` -- explicit ID
  - `text(id, content, opts)` -- explicit ID with options

  ## Example

      text("Hello, world!")
      text("greeting", "Hello, world!", size: 18)
  """
  defmacro text(content) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      Toddy.Widget.Text.new(unquote(compile_auto_id(caller_mod, caller_line)), unquote(content))
      |> Toddy.Widget.Text.build()
    end
  end

  @doc false
  defmacro text(id, content) do
    quote do
      Toddy.Widget.Text.new(unquote(id), unquote(content)) |> Toddy.Widget.Text.build()
    end
  end

  @doc false
  defmacro text(id, content, opts) do
    quote do
      Toddy.Widget.Text.new(unquote(id), unquote(content), unquote(opts))
      |> Toddy.Widget.Text.build()
    end
  end

  @doc """
  Horizontal or vertical divider.

  ## Example

      rule(width: :fill)
  """
  defmacro rule(opts \\ []) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      opts = unquote(opts)
      id = Keyword.get(opts, :id) || unquote(compile_auto_id(caller_mod, caller_line))
      clean_opts = Keyword.drop(opts, [:id, :do])
      Toddy.Widget.Rule.new(id, clean_opts) |> Toddy.Widget.Rule.build()
    end
  end

  @doc """
  Progress indicator.

  ## Forms

  - `progress_bar(range, value)` -- auto-generated ID (sugar)
  - `progress_bar(id, range, value)` -- explicit ID
  - `progress_bar(id, range, value, opts)` -- explicit ID with options

  ## Arguments

  - `range` -- `{min, max}` tuple defining the full range
  - `value` -- current value within the range

  ## Example

      progress_bar({0, 100}, model.progress)
      progress_bar("dl_progress", {0, 100}, model.progress, height: 8)
  """
  defmacro progress_bar(range, value) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      Toddy.Widget.ProgressBar.new(
        unquote(compile_auto_id(caller_mod, caller_line)),
        unquote(range),
        unquote(value)
      )
      |> Toddy.Widget.ProgressBar.build()
    end
  end

  @doc false
  defmacro progress_bar(id, range, value) do
    quote do
      Toddy.Widget.ProgressBar.new(unquote(id), unquote(range), unquote(value))
      |> Toddy.Widget.ProgressBar.build()
    end
  end

  @doc false
  defmacro progress_bar(id, range, value, opts) do
    quote do
      Toddy.Widget.ProgressBar.new(unquote(id), unquote(range), unquote(value), unquote(opts))
      |> Toddy.Widget.ProgressBar.build()
    end
  end

  # ---------------------------------------------------------------------------
  # Additional input widgets
  # ---------------------------------------------------------------------------

  @doc """
  Toggle switch.

  Emits `%Widget{type: :toggle, id: id, value: boolean}` when toggled.

  ## Example

      toggler("dark_mode", model.dark_mode, label: "Dark mode")
  """
  @spec toggler(id :: String.t(), is_toggled :: boolean(), opts :: keyword()) ::
          Toddy.Widget.ui_node()
  def toggler(id, is_toggled, opts \\ [])

  def toggler(id, is_toggled, opts) when not is_keyword(is_toggled) do
    Toddy.Widget.Toggler.new(id, is_toggled, clean_opts(opts)) |> Toddy.Widget.Toggler.build()
  end

  @doc """
  Radio button for single-value selection from a group.

  Use the `group` option so all radios in the same group emit select events
  with the group name as the ID instead of each radio's individual ID.

  ## Example

      radio("size_sm", "small", model.size, label: "Small", group: "size")
      radio("size_lg", "large", model.size, label: "Large", group: "size")
  """
  @spec radio(
          id :: String.t(),
          value :: String.t(),
          selected :: String.t() | nil,
          opts :: keyword()
        ) ::
          Toddy.Widget.ui_node()
  def radio(id, value, selected, opts \\ [])

  def radio(id, value, selected, opts) when not is_keyword(value) and not is_keyword(selected) do
    Toddy.Widget.Radio.new(id, value, selected, clean_opts(opts)) |> Toddy.Widget.Radio.build()
  end

  @doc """
  Horizontal slider for numeric range input.

  ## Arguments

  - `range` -- `{min, max}` tuple or `min..max` Range
  - `value` -- current value

  ## Example

      slider("volume", {0, 100}, model.volume, step: 5)
      slider("volume", 0..100, model.volume, step: 5)
  """
  @spec slider(
          id :: String.t(),
          range :: {number(), number()} | Range.t(),
          value :: number(),
          opts :: keyword()
        ) ::
          Toddy.Widget.ui_node()
  def slider(id, range, value, opts \\ [])

  def slider(id, range, value, opts) when not is_keyword(range) and not is_keyword(value) do
    Toddy.Widget.Slider.new(id, normalize_range(range), value, clean_opts(opts))
    |> Toddy.Widget.Slider.build()
  end

  @doc """
  Vertical slider for numeric range input.

  Same as `slider/4` but oriented vertically. Accepts `{min, max}` or `min..max`.

  ## Example

      vertical_slider("brightness", {0, 100}, model.brightness)
      vertical_slider("brightness", 0..100, model.brightness)
  """
  @spec vertical_slider(
          id :: String.t(),
          range :: {number(), number()} | Range.t(),
          value :: number(),
          opts :: keyword()
        ) ::
          Toddy.Widget.ui_node()
  def vertical_slider(id, range, value, opts \\ [])

  def vertical_slider(id, range, value, opts)
      when not is_keyword(range) and not is_keyword(value) do
    Toddy.Widget.VerticalSlider.new(id, normalize_range(range), value, clean_opts(opts))
    |> Toddy.Widget.VerticalSlider.build()
  end

  @doc """
  Dropdown pick list for selecting from a list of options.

  ## Example

      pick_list("country", ["UK", "US", "DE"], model.country, placeholder: "Choose...")
  """
  @spec pick_list(
          id :: String.t(),
          options :: [String.t()],
          selected :: String.t() | nil,
          opts :: keyword()
        ) :: Toddy.Widget.ui_node()
  def pick_list(id, options, selected, opts \\ [])

  def pick_list(id, options, selected, opts)
      when not is_keyword(options) and not is_keyword(selected) do
    Toddy.Widget.PickList.new(id, options, [{:selected, selected} | clean_opts(opts)])
    |> Toddy.Widget.PickList.build()
  end

  @doc """
  Combo box with free-text input and dropdown suggestions.

  ## Example

      combo_box("lang", ["Elixir", "Rust", "Go"], model.lang, placeholder: "Type...")
  """
  @spec combo_box(
          id :: String.t(),
          options :: [String.t()],
          value :: String.t(),
          opts :: keyword()
        ) ::
          Toddy.Widget.ui_node()
  def combo_box(id, options, value, opts \\ [])

  def combo_box(id, options, value, opts)
      when not is_keyword(options) and not is_keyword(value) do
    Toddy.Widget.ComboBox.new(id, options, [{:value, value} | clean_opts(opts)])
    |> Toddy.Widget.ComboBox.build()
  end

  @doc """
  Multi-line text editor.

  ## Example

      text_editor("notes", model.notes, width: :fill, height: 200)
  """
  @spec text_editor(id :: String.t(), content :: String.t(), opts :: keyword()) ::
          Toddy.Widget.ui_node()
  def text_editor(id, content, opts \\ [])

  def text_editor(id, content, opts) when not is_keyword(content) do
    Toddy.Widget.TextEditor.new(id, [{:content, content} | clean_opts(opts)])
    |> Toddy.Widget.TextEditor.build()
  end

  # ---------------------------------------------------------------------------
  # Additional display widgets
  # ---------------------------------------------------------------------------

  @doc """
  Raster image display.

  ## Example

      image("logo", "/assets/logo.png", width: 200, content_fit: :cover)
  """
  @spec image(id :: String.t(), source :: String.t(), opts :: keyword()) :: Toddy.Widget.ui_node()
  def image(id, source, opts \\ [])

  def image(id, source, opts) when not is_keyword(source) do
    Toddy.Widget.Image.new(id, source, clean_opts(opts)) |> Toddy.Widget.Image.build()
  end

  @doc """
  SVG image display.

  ## Example

      svg("icon", "/assets/icon.svg", width: 24, height: 24)
  """
  @spec svg(id :: String.t(), source :: String.t(), opts :: keyword()) :: Toddy.Widget.ui_node()
  def svg(id, source, opts \\ [])

  def svg(id, source, opts) when not is_keyword(source) do
    Toddy.Widget.Svg.new(id, source, clean_opts(opts)) |> Toddy.Widget.Svg.build()
  end

  @doc """
  Markdown content renderer.

  ## Forms

  - `markdown(content)` -- auto-generated ID
  - `markdown(id, content)` -- explicit ID
  - `markdown(id, content, opts)` -- explicit ID with options

  ## Example

      markdown("# Hello\\n\\nSome **bold** text")
      markdown("my_md", "# Hello", code_theme: "dracula")
  """
  defmacro markdown(content) do
    caller_mod = __CALLER__.module
    caller_line = __CALLER__.line

    quote do
      Toddy.Widget.Markdown.new(
        unquote(compile_auto_id(caller_mod, caller_line)),
        unquote(content)
      )
      |> Toddy.Widget.Markdown.build()
    end
  end

  @doc false
  defmacro markdown(id, content) do
    quote do
      Toddy.Widget.Markdown.new(unquote(id), unquote(content)) |> Toddy.Widget.Markdown.build()
    end
  end

  @doc false
  defmacro markdown(id, content, opts) do
    quote do
      Toddy.Widget.Markdown.new(unquote(id), unquote(content), unquote(opts))
      |> Toddy.Widget.Markdown.build()
    end
  end

  # ---------------------------------------------------------------------------
  # Additional layout widgets (macros with do block support)
  # ---------------------------------------------------------------------------

  # -- tooltip(id, tip, opts) --------------------------------------------------

  @doc """
  Tooltip wrapper. Children are the content being tooltipped.

  ## Forms

  - `tooltip(id, tip, do: block)` -- with children
  - `tooltip(id, tip, opts, do: block)` -- with children and options

  ## Example

      tooltip "save_tip", "Save your work", position: :top do
        button("save", "Save")
      end
  """
  defmacro tooltip(id, tip_or_do) do
    case tip_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Tooltip, unquote(id), [], children, nil)
        end

      tip when is_binary(tip) ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Tooltip,
            unquote(id),
            [tip: unquote(tip)],
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro tooltip(id, tip, opts_or_do) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

          Toddy.UI.__build_container__(
            Toddy.Widget.Tooltip,
            unquote(id),
            [tip: unquote(tip)],
            children,
            nil
          )
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(
            Toddy.Widget.Tooltip,
            unquote(id),
            [tip: unquote(tip)] ++ unquote(opts),
            [],
            nil
          )
        end
    end
  end

  @doc false
  defmacro tooltip(id, tip, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.Tooltip,
        unquote(id),
        [tip: unquote(tip)] ++ unquote(opts),
        children,
        nil
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Canvas (function -- no children)
  # ---------------------------------------------------------------------------

  @doc """
  Canvas for drawing shapes organized into named layers. No children.

  ## Options

  - `:layers` -- map of layer names to shape descriptor lists
  - `:width` / `:height` -- dimensions
  - `:background` -- background color

  ## Example

      canvas("drawing",
        layers: %{"main" => [%{"type" => "circle", "x" => 50, "y" => 50, "r" => 20}]},
        width: 400,
        height: 300
      )
  """
  @spec canvas(id :: String.t(), opts :: keyword()) :: Toddy.Widget.ui_node()
  def canvas(id, opts \\ []) do
    Toddy.Widget.Canvas.new(id, clean_opts(opts)) |> Toddy.Widget.Canvas.build()
  end

  # -- pane_grid(id, opts) ----------------------------------------------------

  @doc """
  Pane grid for resizable tiled panes.

  ## Options

  - `:spacing` -- gap between panes
  - `:min_size` -- minimum pane size
  - `:on_resize` -- resize event tag
  - `:on_drag` -- drag event tag
  - `:on_click` -- click event tag

  Children are pane content keyed by ID.

  ## Example

      pane_grid "editor_panes", spacing: 2 do
        column id: "left" do
          text("Left pane")
        end
        column id: "right" do
          text("Right pane")
        end
      end
  """
  defmacro pane_grid(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.PaneGrid, unquote(id), [], children, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.PaneGrid, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro pane_grid(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)

      Toddy.UI.__build_container__(
        Toddy.Widget.PaneGrid,
        unquote(id),
        unquote(opts),
        children,
        nil
      )
    end
  end

  # -- rich_text(id, opts) ----------------------------------------------------

  @doc """
  Rich text display with styled spans.

  ## Options

  - `:spans` -- list of span descriptors
  - `:width` -- width

  ## Example

      rich_text("styled", spans: [%{text: "bold", weight: :bold}, %{text: " normal"}])
  """
  @spec rich_text(id :: String.t(), opts :: keyword()) :: Toddy.Widget.ui_node()
  def rich_text(id, opts \\ []) do
    Toddy.Widget.RichText.new(id, clean_opts(opts)) |> Toddy.Widget.RichText.build()
  end

  # -- table(id, opts) --------------------------------------------------------

  @doc """
  Data table widget.

  ## Options

  - `:columns` -- list of column descriptors (`%{key, label, width}`)
  - `:rows` -- list of row data maps

  The `do` block can contain row content templates (e.g. for custom cell
  rendering). Children from the block are stored in `:children`.

  ## Examples

      table("users", columns: cols, rows: data)

      table "users", columns: cols, rows: data do
        text("custom footer")
      end
  """
  defmacro table(id, opts_or_do \\ []) do
    case opts_or_do do
      [do: block] ->
        exprs = block_to_exprs(block)

        quote do
          children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
          Toddy.UI.__build_container__(Toddy.Widget.Table, unquote(id), [], children, nil)
        end

      opts ->
        quote do
          Toddy.UI.__build_container__(Toddy.Widget.Table, unquote(id), unquote(opts), [], nil)
        end
    end
  end

  @doc false
  defmacro table(id, opts, do: block) do
    exprs = block_to_exprs(block)

    quote do
      children = [unquote_splicing(exprs)] |> List.flatten() |> Enum.reject(&is_nil/1)
      Toddy.UI.__build_container__(Toddy.Widget.Table, unquote(id), unquote(opts), children, nil)
    end
  end

  # __build_fixed_node__ removed -- use __build_container__

  # ---------------------------------------------------------------------------
  # Tree query
  # ---------------------------------------------------------------------------

  @doc """
  Finds the first node in a tree whose `:id` matches `id`.

  Delegates to `Toddy.Tree.find/2`. Returns the node map or `nil`.

  ## Example

      tree = MyApp.view(model)
      Toddy.UI.find(tree, "save_button")
  """
  @spec find(tree :: Toddy.Widget.ui_node(), id :: String.t()) :: Toddy.Widget.ui_node() | nil
  defdelegate find(tree, id), to: Toddy.Tree

  @doc "Returns true if a node with `id` exists in the tree."
  @spec exists?(tree :: Toddy.Widget.ui_node() | nil, id :: String.t()) :: boolean()
  defdelegate exists?(tree, id), to: Toddy.Tree

  @doc "Returns all node IDs in the tree."
  @spec ids(tree :: Toddy.Widget.ui_node() | nil) :: [String.t()]
  defdelegate ids(tree), to: Toddy.Tree

  @doc "Finds all nodes matching a predicate."
  @spec find_all(
          tree :: Toddy.Widget.ui_node() | nil,
          id_or_pred :: String.t() | (Toddy.Widget.ui_node() -> boolean())
        ) ::
          [Toddy.Widget.ui_node()]
  defdelegate find_all(tree, id_or_pred), to: Toddy.Tree

  # ---------------------------------------------------------------------------
  # QR Code (function -- no children)
  # ---------------------------------------------------------------------------

  @doc """
  QR code display. No children.

  ## Arguments

  - `id` -- unique identifier
  - `data` -- the string to encode

  ## Options

  - `:cell_size` -- size of each QR module in pixels (default 4.0)
  - `:cell_color` -- color of dark modules
  - `:background_color` -- color of light modules
  - `:error_correction` -- `:low`, `:medium` (default), `:quartile`, `:high`

  ## Example

      qr_code("my_qr", "https://example.com", cell_size: 6)
  """
  @spec qr_code(id :: String.t(), data :: String.t(), opts :: keyword()) :: Toddy.Widget.ui_node()
  def qr_code(id, data, opts \\ []) do
    Toddy.Widget.QrCode.new(id, data, clean_opts(opts)) |> Toddy.Widget.QrCode.build()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @reserved_keys [:children, :id, :do]

  defp clean_opts(opts), do: Keyword.drop(opts, @reserved_keys)

  defp normalize_range({min, max}), do: {min, max}
  defp normalize_range(first..last//_), do: {first, last}

  # ---------------------------------------------------------------------------
  # Private macro helpers
  # ---------------------------------------------------------------------------

  defp block_to_exprs({:__block__, _, exprs}), do: exprs
  defp block_to_exprs(single_expr), do: [single_expr]
end
