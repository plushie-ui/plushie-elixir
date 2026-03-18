defmodule Julep.Extension do
  @moduledoc """
  Macro-based DSL for declaring Julep widget extensions.

  Supports two kinds of extension:

  - `:native_widget` -- backed by a Rust crate implementing the
    `WidgetExtension` trait. Requires `rust_crate` and `rust_constructor`
    declarations.
  - `:widget` -- pure Elixir widget, either a direct node builder or a
    composite that defines `render/2` or `render/3`.

  ## Usage

      defmodule MyApp.Gauge do
        use Julep.Extension, :native_widget

        widget :gauge

        prop :value, :number
        prop :min, :number, default: 0
        prop :max, :number, default: 100
        prop :color, :color, default: :blue
        prop :width, :length
        prop :height, :length

        rust_crate "native/my_gauge"
        rust_constructor "my_gauge::GaugeExtension::new()"

        command :set_value, value: :number
      end

  ## Generated code

  The macro generates:

  - `type_names/0` -- returns `[:gauge]` (from the `widget` declaration)
  - `native_crate/0` -- returns the `rust_crate` path (native_widget only)
  - `rust_constructor/0` -- returns the Rust expression (native_widget only)
  - `new/2` -- creates a `%Module{}` struct (or a node map for composites)
  - Setter functions per prop for pipeline composition
  - `with_options/2` -- applies keyword options via setters
  - `build/1` -- converts the struct to a `ui_node()` map
  - `@type t`, `@type option` -- typespecs for dialyzer
  - `Julep.Iced.Widget` protocol implementation
  - Command functions (native_widget only) that wrap
    `Julep.Command.extension_command/3`

  ## Prop types

  Supported prop types and their encoding:

  - `:number`, `:string`, `:boolean` -- pass through
  - `:color` -- normalized via `Julep.Iced.Color.cast/1`
  - `:length` -- encoded via `Julep.Iced.Encode.encode/1`
  - `:padding` -- encoded via `Julep.Iced.Encode.encode/1`
  - `:alignment` -- encoded via `Julep.Iced.Encode.encode/1`
  - `:font` -- pass through
  - `:style` -- pass through (atom or StyleMap)
  - `:atom` -- converted to string via `Atom.to_string/1`
  - `:map`, `:any` -- pass through
  - `{:list, _}` -- pass through

  ## Composite widgets

  If the using module defines `render/2` (leaf) or `render/3` (container),
  `new/2` delegates to it after resolving props:

      defmodule MyApp.LabeledInput do
        use Julep.Extension, :widget

        widget :labeled_input, container: true

        prop :label, :string

        def render(id, props, children) do
          import Julep.UI
          column id: id do
            text(props.label)
            Enum.map(children, & &1)
          end
        end
      end

  ### render/2 vs render/3

  Use `render/2` for leaf composites that do not accept children:

      def render(id, props) do
        %{id: id, type: "text", props: %{"content" => props.label}, children: []}
      end

  Use `render/3` for container composites that accept children. When
  `container: true` is set on the `widget` declaration, you must define
  `render/3` (not `render/2`):

      def render(id, props, children) do
        %{id: id, type: "column", props: %{}, children: children}
      end

  ## Special options

  All widgets automatically support the `:a11y` option for accessibility
  overrides (see `Julep.Iced.A11y`). It does not need to be declared via
  `prop` -- it is always available on `new/2`.
  """

  # -- Behaviour callbacks ---------------------------------------------------

  @doc "Node type atoms this extension handles."
  @callback type_names() :: [atom()]

  @doc "Path to the Rust crate relative to the package root."
  @callback native_crate() :: String.t()

  @doc "Full Rust constructor expression for the extension."
  @callback rust_constructor() :: String.t()

  @doc """
  Infers the mock event produced by a verb applied to an extension widget.

  Called by the mock test backend when the built-in `EventMap` does not
  recognize the widget type. Return `{:ok, event_tuple}` to handle,
  `{:error, reason}` for a known-bad interaction, or `:not_handled`
  to fall through to the default error.

  Optional -- extensions that don't implement this callback will behave
  as if they returned `:not_handled` for every verb.
  """
  @callback sim_events(verb :: atom(), element :: Julep.Test.Element.t(), args :: list()) ::
              {:ok, tuple()} | {:error, String.t()} | :not_handled

  @optional_callbacks [sim_events: 3, native_crate: 0, rust_constructor: 0]

  # -- __using__ -------------------------------------------------------------

  defmacro __using__(kind) when kind not in [:native_widget, :widget] do
    raise ArgumentError,
          "Julep.Extension kind must be :native_widget or :widget, got: #{inspect(kind)}"
  end

  defmacro __using__(kind) when kind in [:native_widget, :widget] do
    common =
      quote do
        @behaviour Julep.Extension
        @_extension_kind unquote(kind)

        Module.register_attribute(__MODULE__, :_extension_props, accumulate: true)
        Module.register_attribute(__MODULE__, :_extension_commands, accumulate: true)
        Module.put_attribute(__MODULE__, :_extension_widget, nil)
        Module.put_attribute(__MODULE__, :_extension_container, false)
      end

    imports =
      if kind == :native_widget do
        quote do
          import Julep.Extension,
            only: [
              widget: 1,
              widget: 2,
              prop: 2,
              prop: 3,
              command: 1,
              command: 2,
              rust_crate: 1,
              rust_constructor: 1
            ]

          Module.put_attribute(__MODULE__, :_rust_crate, nil)
          Module.put_attribute(__MODULE__, :_rust_constructor, nil)
        end
      else
        quote do
          import Julep.Extension, only: [widget: 1, widget: 2, prop: 2, prop: 3]
          import Julep.UI
        end
      end

    before_compile =
      quote do
        @before_compile Julep.Extension
      end

    [common, imports, before_compile]
  end

  # -- DSL macros ------------------------------------------------------------

  @doc "Declares the widget type name. Pass `container: true` for container widgets."
  defmacro widget(type_name, opts \\ []) do
    quote do
      if @_extension_widget do
        IO.warn(
          "widget type already declared as #{inspect(@_extension_widget)}, overwriting with #{inspect(unquote(type_name))}"
        )
      end

      @_extension_widget unquote(type_name)
      @_extension_container unquote(Keyword.get(opts, :container, false))
    end
  end

  @doc "Declares a prop with name, type, and optional default."
  defmacro prop(name, type, opts \\ []) do
    quote do
      @_extension_props {unquote(name), unquote(type), unquote(opts)}
    end
  end

  @doc "Declares a command (native_widget only) with optional typed params."
  defmacro command(name, params \\ []) do
    quote do
      @_extension_commands {unquote(name), unquote(params)}
    end
  end

  @doc "Declares the path to the Rust crate (native_widget only)."
  defmacro rust_crate(path) do
    quote do
      @_rust_crate unquote(path)
    end
  end

  @doc "Declares the Rust constructor expression (native_widget only)."
  defmacro rust_constructor(expr) do
    quote do
      @_rust_constructor unquote(expr)
    end
  end

  # -- __before_compile__ ----------------------------------------------------

  @known_prop_types [
    :number,
    :string,
    :boolean,
    :color,
    :length,
    :padding,
    :alignment,
    :style,
    :font,
    :atom,
    :map,
    :any
  ]

  defmacro __before_compile__(env) do
    kind = Module.get_attribute(env.module, :_extension_kind)
    widget_type = Module.get_attribute(env.module, :_extension_widget)
    container = Module.get_attribute(env.module, :_extension_container)
    props = Module.get_attribute(env.module, :_extension_props) |> Enum.reverse()
    commands = Module.get_attribute(env.module, :_extension_commands) |> Enum.reverse()

    validate_declarations!(env, kind, widget_type)
    validate_prop_types!(env, props)
    validate_command_types!(commands)
    warn_duplicate_props(env, props)
    validate_reserved_names!(env, props)
    validate_render_arity!(env, container)

    rust_crate_val = Module.get_attribute(env.module, :_rust_crate)
    rust_constructor_val = Module.get_attribute(env.module, :_rust_constructor)
    has_render_3 = Module.defines?(env.module, {:render, 3})
    is_composite = Module.defines?(env.module, {:render, 2}) or has_render_3
    type_string = Atom.to_string(widget_type)

    behaviour_fns =
      generate_behaviour_fns(kind, widget_type, rust_crate_val, rust_constructor_val)

    widget_code =
      if is_composite do
        prop_validation = generate_prop_validation(props)
        generate_composite_new(type_string, container, props, prop_validation, has_render_3)
      else
        generate_struct_widget(env.module, type_string, container, props)
      end

    command_fns = generate_commands(commands)
    prop_names_fn = generate_prop_names(props)

    quote do
      unquote(behaviour_fns)
      unquote(widget_code)
      unquote(command_fns)
      unquote(prop_names_fn)
    end
  end

  defp validate_declarations!(env, kind, widget_type) do
    unless widget_type do
      raise CompileError,
        file: env.file,
        line: 0,
        description: "missing `widget :type_name` declaration in #{inspect(env.module)}"
    end

    if kind == :native_widget do
      unless Module.get_attribute(env.module, :_rust_crate) do
        raise CompileError,
          file: env.file,
          line: 0,
          description: "missing `rust_crate \"path\"` in #{inspect(env.module)}"
      end

      unless Module.get_attribute(env.module, :_rust_constructor) do
        raise CompileError,
          file: env.file,
          line: 0,
          description: "missing `rust_constructor \"expr\"` in #{inspect(env.module)}"
      end
    end
  end

  defp validate_prop_types!(env, props) do
    for {name, type, _opts} <- props do
      unless valid_type?(type) do
        raise CompileError,
          file: env.file,
          line: 0,
          description:
            "unsupported prop type #{inspect(type)} for prop #{inspect(name)} in #{inspect(env.module)}. Supported: #{inspect(@known_prop_types)}"
      end
    end
  end

  defp validate_command_types!(commands) do
    for {cmd_name, params} <- commands, {param_name, type} <- params do
      unless valid_type?(type) do
        raise CompileError,
          description:
            "unsupported command param type #{inspect(type)} for param #{inspect(param_name)} in command #{inspect(cmd_name)}"
      end
    end
  end

  defp warn_duplicate_props(env, props) do
    prop_names = Enum.map(props, fn {name, _, _} -> name end)
    dupes = prop_names -- Enum.uniq(prop_names)

    if dupes != [] do
      IO.warn("duplicate prop names in #{inspect(env.module)}: #{inspect(Enum.uniq(dupes))}")
    end
  end

  @reserved_prop_names [:id, :type, :children, :a11y, :do]

  defp validate_reserved_names!(env, props) do
    for {name, _type, _opts} <- props, name in @reserved_prop_names do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "prop name #{inspect(name)} is reserved in #{inspect(env.module)}. " <>
            "Reserved names: #{inspect(@reserved_prop_names)}"
    end
  end

  defp validate_render_arity!(env, container) do
    has_render_2 = Module.defines?(env.module, {:render, 2})
    has_render_3 = Module.defines?(env.module, {:render, 3})

    if container and has_render_2 and not has_render_3 do
      raise CompileError,
        file: env.file,
        line: 0,
        description:
          "#{inspect(env.module)} declares container: true but defines render/2 instead of render/3. Container widgets must accept children via render/3."
    end
  end

  defp valid_type?(type) when type in @known_prop_types, do: true
  defp valid_type?({:list, inner}) when inner in @known_prop_types, do: true
  defp valid_type?(_), do: false

  # -- Code generation helpers (called at compile time) ----------------------

  @doc false
  def generate_behaviour_fns(kind, widget_type, rust_crate_val, rust_constructor_val) do
    base =
      quote do
        @impl Julep.Extension
        def type_names, do: [unquote(widget_type)]
      end

    if kind == :native_widget do
      quote do
        unquote(base)

        @impl Julep.Extension
        def native_crate, do: unquote(rust_crate_val)

        @impl Julep.Extension
        def rust_constructor, do: unquote(rust_constructor_val)
      end
    else
      base
    end
  end

  @doc false
  def generate_prop_names(props) do
    known =
      Enum.map(props, fn {name, _type, _opts} -> name end)
      |> Kernel.++([:a11y])

    quote do
      @doc false
      def __prop_names__, do: unquote(known)
    end
  end

  @doc false
  def generate_struct_widget(module, type_string, container, props) do
    struct_def = generate_struct_and_types(props, container)
    new_fn = generate_struct_new(container)
    with_options_fn = generate_with_options(props)
    setters = generate_setters(props)
    build_fn = generate_build()
    protocol_impl = generate_widget_protocol(module, type_string, container, props)

    quote do
      unquote(struct_def)
      unquote(new_fn)
      unquote(with_options_fn)
      unquote_splicing(setters)
      unquote(build_fn)
      unquote(protocol_impl)
    end
  end

  defp generate_composite_new(_type_string, container, props, prop_extract, has_render_3) do
    prop_struct_fields =
      for {name, _type, opts} <- props do
        default = Keyword.get(opts, :default)
        {name, default}
      end

    if container or has_render_3 do
      quote do
        @spec new(id :: String.t(), opts :: keyword()) :: Julep.Iced.ui_node()
        def new(id, opts \\ []) when is_binary(id) do
          {children, opts} = Keyword.pop(opts, :do, [])
          children = List.wrap(children)
          {a11y_val, opts} = Keyword.pop(opts, :a11y)

          prop_defaults = unquote(Macro.escape(prop_struct_fields))
          unquote(prop_extract)

          props_map =
            prop_defaults
            |> Enum.map(fn {name, default} ->
              {name, Keyword.get(opts, name, default)}
            end)
            |> Enum.reject(fn {_name, val} -> is_nil(val) end)
            |> Map.new()

          props_map =
            if a11y_val, do: Map.put(props_map, :a11y, a11y_val), else: props_map

          render(id, props_map, children)
        end
      end
    else
      quote do
        @spec new(id :: String.t(), opts :: keyword()) :: Julep.Iced.ui_node()
        def new(id, opts \\ []) when is_binary(id) do
          {a11y_val, opts} = Keyword.pop(opts, :a11y)

          prop_defaults = unquote(Macro.escape(prop_struct_fields))
          unquote(prop_extract)

          props_map =
            prop_defaults
            |> Enum.map(fn {name, default} ->
              {name, Keyword.get(opts, name, default)}
            end)
            |> Enum.reject(fn {_name, val} -> is_nil(val) end)
            |> Map.new()

          props_map =
            if a11y_val, do: Map.put(props_map, :a11y, a11y_val), else: props_map

          render(id, props_map)
        end
      end
    end
  end

  # -- Struct-based widget generation -----------------------------------------
  #
  # For non-composite widgets (no render/2 or render/3), we generate:
  # - defstruct with all props + :id + :a11y
  # - @type t with proper field types
  # - @type option union of keyword tuples
  # - new/2 that creates a struct and applies keyword options
  # - with_options/2 that reduces options through setter functions
  # - A setter function per prop with encoding and guards
  # - a11y/2 setter for accessibility overrides
  # - build/1 convenience that calls the protocol
  # - Julep.Iced.Widget protocol implementation (to_node)

  defp generate_struct_and_types(props, container) do
    prop_fields =
      Enum.map(props, fn {name, _type, opts} -> {name, Keyword.get(opts, :default)} end)

    struct_fields =
      [{:id, nil} | prop_fields] ++
        if(container, do: [{:children, []}], else: []) ++
        [{:a11y, nil}]

    prop_type_fields = Enum.map(props, &prop_type_ast/1)

    type_fields =
      [{:id, quote(do: String.t())} | prop_type_fields] ++
        if(container, do: [{:children, quote(do: [Julep.Iced.ui_node()])}], else: []) ++
        [{:a11y, quote(do: Julep.Iced.A11y.t() | nil)}]

    option_variants =
      Enum.map(props, fn {name, type, _opts} ->
        quote(do: {unquote(name), unquote(elixir_type_for(type))})
      end) ++ [quote(do: {:a11y, Julep.Iced.A11y.t()})]

    quote do
      defstruct unquote(struct_fields)

      @type t :: %__MODULE__{unquote_splicing(type_fields)}

      @type option :: unquote(union_type(option_variants))
    end
  end

  defp prop_type_ast({name, type, _opts}) do
    {name, quote(do: unquote(elixir_type_for(type)) | nil)}
  end

  defp elixir_type_for(:number), do: quote(do: number())
  defp elixir_type_for(:string), do: quote(do: String.t())
  defp elixir_type_for(:boolean), do: quote(do: boolean())
  defp elixir_type_for(:color), do: quote(do: Julep.Iced.Color.t())
  defp elixir_type_for(:length), do: quote(do: Julep.Iced.Length.t())
  defp elixir_type_for(:padding), do: quote(do: Julep.Iced.Padding.t())
  defp elixir_type_for(:alignment), do: quote(do: Julep.Iced.Alignment.t())
  defp elixir_type_for(:font), do: quote(do: Julep.Iced.Font.t())
  defp elixir_type_for(:style), do: quote(do: atom() | Julep.Iced.StyleMap.t())
  defp elixir_type_for(:atom), do: quote(do: atom())
  defp elixir_type_for(:map), do: quote(do: map())
  defp elixir_type_for(:any), do: quote(do: term())
  defp elixir_type_for({:list, inner}), do: quote(do: [unquote(elixir_type_for(inner))])

  defp union_type([single]), do: single

  defp union_type([head | tail]) do
    Enum.reduce(tail, head, fn variant, acc ->
      quote(do: unquote(acc) | unquote(variant))
    end)
  end

  defp generate_struct_new(container) do
    if container do
      quote do
        @doc "Creates a new widget struct with the given ID and keyword options."
        @spec new(id :: String.t(), opts :: [option()]) :: t()
        def new(id, opts \\ []) when is_binary(id) do
          {children, opts} = Keyword.pop(opts, :do, [])
          widget = %__MODULE__{id: id} |> with_options(opts)
          %{widget | children: List.wrap(children)}
        end
      end
    else
      quote do
        @doc "Creates a new widget struct with the given ID and keyword options."
        @spec new(id :: String.t(), opts :: [option()]) :: t()
        def new(id, opts \\ []) when is_binary(id) do
          %__MODULE__{id: id} |> with_options(opts)
        end
      end
    end
  end

  defp generate_with_options(props) do
    v = Macro.var(:v, __MODULE__)
    acc = Macro.var(:acc, __MODULE__)
    key = Macro.var(:key, __MODULE__)

    prop_clauses =
      Enum.map(props, fn {name, _type, _opts} ->
        {:->, [],
         [
           [{:{}, [], [name, v]}, acc],
           quote(do: __MODULE__.unquote(name)(unquote(acc), unquote(v)))
         ]}
      end)

    a11y_clause =
      {:->, [],
       [
         [{:{}, [], [:a11y, v]}, acc],
         quote(do: __MODULE__.a11y(unquote(acc), unquote(v)))
       ]}

    unknown_v = Macro.var(:_, __MODULE__)
    unknown_acc = Macro.var(:_, __MODULE__)

    unknown_clause =
      {:->, [],
       [
         [{:{}, [], [key, unknown_v]}, unknown_acc],
         quote do
           raise ArgumentError,
                 "unknown option #{inspect(unquote(key))} for #{inspect(__MODULE__)}.new"
         end
       ]}

    all_clauses = prop_clauses ++ [a11y_clause, unknown_clause]
    reducer_fn = {:fn, [], all_clauses}

    quote do
      @doc "Applies keyword options to an existing widget struct."
      @spec with_options(widget :: t(), opts :: [option()]) :: t()
      def with_options(%__MODULE__{} = widget, []), do: widget

      def with_options(%__MODULE__{} = widget, opts) do
        Enum.reduce(opts, widget, unquote(reducer_fn))
      end
    end
  end

  defp generate_setters(props) do
    prop_setters =
      Enum.map(props, fn {name, type, opts} ->
        doc = Keyword.get(opts, :doc, "Sets the `#{name}` prop.")
        encoder = encoder_for_type(type)
        value_type = elixir_type_for(type)

        case setter_guard(type) do
          nil ->
            quote do
              @doc unquote(doc)
              @spec unquote(name)(widget :: t(), value :: unquote(value_type)) :: t()
              def unquote(name)(%__MODULE__{} = widget, value) do
                %{widget | unquote(name) => unquote(encoder).(value)}
              end
            end

          guard ->
            quote do
              @doc unquote(doc)
              @spec unquote(name)(widget :: t(), value :: unquote(value_type)) :: t()
              def unquote(name)(%__MODULE__{} = widget, value) when unquote(guard) do
                %{widget | unquote(name) => unquote(encoder).(value)}
              end
            end
        end
      end)

    a11y_setter =
      quote do
        @doc "Sets accessibility annotations."
        @spec a11y(widget :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
        def a11y(%__MODULE__{} = widget, a11y) do
          %{widget | a11y: Julep.Iced.A11y.cast(a11y)}
        end
      end

    prop_setters ++ [a11y_setter]
  end

  defp setter_guard(:number), do: quote(do: is_number(value))
  defp setter_guard(:string), do: quote(do: is_binary(value))
  defp setter_guard(:boolean), do: quote(do: is_boolean(value))
  defp setter_guard(:atom), do: quote(do: is_atom(value))
  defp setter_guard(:map), do: quote(do: is_map(value))
  defp setter_guard({:list, _}), do: quote(do: is_list(value))
  defp setter_guard(_), do: nil

  defp generate_build do
    quote do
      @doc "Converts this widget struct to a `ui_node()` map."
      @spec build(widget :: t()) :: Julep.Iced.ui_node()
      def build(%__MODULE__{} = widget), do: Julep.Iced.Widget.to_node(widget)
    end
  end

  defp generate_widget_protocol(_module, type_string, container, props) do
    put_calls =
      Enum.map(props, fn {name, type, _opts} ->
        key_string = Atom.to_string(name)
        encoder = protocol_encoder_for_type(type)

        quote do
          props = Julep.Iced.Widget.Build.put_if(props, widget.unquote(name), unquote(key_string), unquote(encoder))
        end
      end)

    a11y_put =
      quote do
        props = Julep.Iced.Widget.Build.put_if(props, widget.a11y, "a11y")
      end

    children =
      if container do
        quote(do: Julep.Iced.Widget.Build.children_to_nodes(widget.children))
      else
        quote(do: [])
      end

    # defimpl must be defined at the top level of the module, not inside a
    # function. We generate the AST here; it's injected via __before_compile__.
    quote do
      defimpl Julep.Iced.Widget do
        def to_node(widget) do
          props = %{}
          unquote_splicing(put_calls)
          unquote(a11y_put)

          %{
            id: widget.id,
            type: unquote(type_string),
            props: props,
            children: unquote(children)
          }
        end
      end
    end
  end

  # Encoder for the protocol (to_node) -- uses the Build.put_if transform pattern.
  # Returns a function AST that encodes the value for the wire.
  defp protocol_encoder_for_type(:color) do
    quote(do: fn val -> Julep.Iced.Color.cast(val) end)
  end

  defp protocol_encoder_for_type(type) when type in [:length, :padding, :alignment, :style] do
    quote(do: fn val -> Julep.Iced.Encode.encode(val) end)
  end

  defp protocol_encoder_for_type(:atom) do
    quote(do: fn
      val when is_atom(val) -> Atom.to_string(val)
      val when is_binary(val) -> val
    end)
  end

  defp protocol_encoder_for_type(_type) do
    quote(do: fn val -> val end)
  end

  @doc false
  def generate_prop_validation(props) do
    known_names = Enum.map(props, fn {name, _type, _opts} -> name end) ++ [:a11y, :do]

    quote do
      unknown_keys = Keyword.keys(opts) -- unquote(known_names)

      if unknown_keys != [] do
        raise ArgumentError,
              "unknown option(s) #{inspect(unknown_keys)} for #{inspect(__MODULE__)}.new"
      end
    end
  end

  defp encoder_for_type(:color) do
    quote do
      fn val -> Julep.Iced.Color.cast(val) end
    end
  end

  defp encoder_for_type(:length) do
    quote do
      fn val -> Julep.Iced.Encode.encode(val) end
    end
  end

  defp encoder_for_type(:padding) do
    quote do
      fn val -> Julep.Iced.Encode.encode(val) end
    end
  end

  defp encoder_for_type(:alignment) do
    quote do
      fn val -> Julep.Iced.Encode.encode(val) end
    end
  end

  defp encoder_for_type(:atom) do
    quote do
      fn val -> Atom.to_string(val) end
    end
  end

  defp encoder_for_type(:style) do
    quote do
      fn val -> Julep.Iced.Encode.encode(val) end
    end
  end

  defp encoder_for_type(_type) do
    # :number, :string, :boolean, :font, :map, :any, {:list, _}
    quote do
      fn val -> val end
    end
  end

  @doc false
  def generate_commands(commands) do
    fns =
      Enum.map(commands, fn {name, params} ->
        param_names = Keyword.keys(params)

        args =
          [quote(do: widget_id) | Enum.map(param_names, fn p -> to_var(p) end)]

        payload_map =
          {:%{}, [],
           Enum.map(param_names, fn p ->
             {p, to_var(p)}
           end)}

        guards = build_command_guards(params)
        op_string = Atom.to_string(name)

        if param_names == [] do
          quote do
            @doc "Sends the `#{unquote(op_string)}` command to the extension widget."
            def unquote(name)(widget_id) when is_binary(widget_id) do
              Julep.Command.extension_command(widget_id, unquote(op_string), %{})
            end
          end
        else
          quote do
            @doc "Sends the `#{unquote(op_string)}` command to the extension widget."
            def unquote(name)(unquote_splicing(args))
                when is_binary(widget_id) and unquote(guards) do
              Julep.Command.extension_command(
                widget_id,
                unquote(op_string),
                unquote(payload_map)
              )
            end
          end
        end
      end)

    quote do
      (unquote_splicing(fns))
    end
  end

  defp build_command_guards([]), do: quote(do: true)

  defp build_command_guards(params) do
    guards =
      Enum.map(params, fn {name, type} ->
        var = to_var(name)
        guard_for_type(var, type)
      end)

    Enum.reduce(guards, fn right, left ->
      quote(do: unquote(left) and unquote(right))
    end)
  end

  defp guard_for_type(var, :number), do: quote(do: is_number(unquote(var)))
  defp guard_for_type(var, :integer), do: quote(do: is_integer(unquote(var)))
  defp guard_for_type(var, :float), do: quote(do: is_float(unquote(var)))
  defp guard_for_type(var, :string), do: quote(do: is_binary(unquote(var)))
  defp guard_for_type(var, :boolean), do: quote(do: is_boolean(unquote(var)))
  defp guard_for_type(var, :atom), do: quote(do: is_atom(unquote(var)))
  defp guard_for_type(var, :map), do: quote(do: is_map(unquote(var)))
  defp guard_for_type(var, :list), do: quote(do: is_list(unquote(var)))
  defp guard_for_type(var, {:list, _}), do: quote(do: is_list(unquote(var)))
  defp guard_for_type(_var, _), do: quote(do: true)

  # Build a simple AST variable reference from an atom name.
  defp to_var(name) when is_atom(name), do: {name, [], nil}
end
