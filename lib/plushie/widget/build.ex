defmodule Plushie.Widget.Build do
  @moduledoc "Internal helpers for widget `to_node/1` implementations."

  @doc "Adds `key => value` to props if value is not nil."
  @spec put_if(props :: map(), value :: term(), key :: atom()) :: map()
  def put_if(props, nil, _key), do: props
  def put_if(props, value, key), do: Map.put(props, key, value)

  @doc "Adds `key => transform.(value)` to props if value is not nil."
  @spec put_if(
          props :: map(),
          value :: term(),
          key :: atom(),
          transform :: (term() -> term())
        ) ::
          map()
  def put_if(props, nil, _key, _transform), do: props
  def put_if(props, value, key, transform), do: Map.put(props, key, transform.(value))

  @doc "Converts a child element to a ui_node() map if it's a widget struct."
  @spec to_node(child :: Plushie.Widget.child()) :: Plushie.Widget.ui_node()
  def to_node(%{id: _, type: _, props: _, children: _} = node), do: node
  def to_node(%_module{} = widget), do: Plushie.Widget.to_node(widget)

  @doc "Converts a list of children (ui_node maps or widget structs) to ui_node() maps."
  @spec children_to_nodes(children :: [Plushie.Widget.child()]) :: [
          Plushie.Widget.ui_node()
        ]
  def children_to_nodes(children), do: Enum.map(children, &to_node/1)

  @doc """
  Returns true if the value is an animation descriptor (Transition,
  Spring, or Sequence). Widget `with_options/2` reducers use this to
  pass animation descriptors through on known prop keys without
  triggering the setter's type guard.
  """
  @spec animation_descriptor?(term()) :: boolean()
  def animation_descriptor?(%Plushie.Animation.Transition{}), do: true
  def animation_descriptor?(%Plushie.Animation.Spring{}), do: true
  def animation_descriptor?(%Plushie.Animation.Sequence{}), do: true
  def animation_descriptor?(_), do: false

  @doc """
  Wraps a widget build pipeline with animation descriptor passthrough.

  Separates animation descriptors (Transition, Spring, Sequence) and the
  `exit:` prop from the opts before calling the build function, then merges
  them onto the resulting node's props.

      Build.build_node(opts, fn widget_opts ->
        Button.new(id, label, widget_opts) |> Button.build()
      end)
  """
  @spec build_node(opts :: keyword(), build_fn :: (keyword() -> Plushie.Widget.ui_node())) ::
          Plushie.Widget.ui_node()
  def build_node(opts, build_fn) when is_list(opts) and is_function(build_fn, 1) do
    {anim_opts, widget_opts} =
      Keyword.split_with(opts, fn
        {:exit, _} -> true
        {_k, v} -> animation_descriptor?(v)
      end)

    node = build_fn.(widget_opts)

    if anim_opts == [] do
      node
    else
      # Convert exit keyword list to map for correct wire encoding.
      # Without this, exit: [max_width: transition(...)] encodes as
      # nested arrays instead of a map.
      anim_props =
        Map.new(anim_opts, fn
          {:exit, exits} when is_list(exits) -> {:exit, Map.new(exits)}
          pair -> pair
        end)

      %{node | props: Map.merge(node.props, anim_props)}
    end
  end

  @doc "Raises ArgumentError for an unknown option key passed to a widget constructor."
  @spec unknown_option!(module :: module(), key :: term()) :: no_return()
  def unknown_option!(module, key) do
    name = module |> Module.split() |> List.last()
    raise ArgumentError, "unknown option #{inspect(key)} for #{name}.new"
  end

  @doc """
  Validates that a widget has at most one child.

  Raises `ArgumentError` if the children list has more than one element.
  The error message includes the widget type and ID for easy diagnosis:

      ** (ArgumentError) container "sidebar" accepts at most 1 child, got 3

  Called at the top of `to_node/1` for single-child wrappers (container,
  tooltip, mouse_area, scrollable, themer, floating, responsive, pin,
  sensor, window).
  """
  @spec validate_single_child!(
          id :: String.t(),
          type :: String.t(),
          children :: [Plushie.Widget.child()]
        ) :: :ok
  def validate_single_child!(_id, _type, []), do: :ok
  def validate_single_child!(_id, _type, [_]), do: :ok

  def validate_single_child!(id, type, children) do
    raise ArgumentError,
          "#{type} #{inspect(id)} accepts at most 1 child, got #{length(children)}"
  end

  @doc """
  Validates that a widget has exactly the expected number of children.

  Raises `ArgumentError` if the children count does not match `expected`.
  The error message includes the widget type, ID, and both the expected
  and actual counts:

      ** (ArgumentError) overlay "popup" requires exactly 2 children, got 1

  Called at the top of `to_node/1` for widgets with strict child count
  requirements (overlay).
  """
  @spec validate_children_count!(
          id :: String.t(),
          type :: String.t(),
          children :: [Plushie.Widget.child()],
          expected :: pos_integer()
        ) :: :ok
  def validate_children_count!(_id, _type, children, expected)
      when length(children) == expected,
      do: :ok

  def validate_children_count!(id, type, children, expected) do
    raise ArgumentError,
          "#{type} #{inspect(id)} requires exactly #{expected} children, got #{length(children)}"
  end
end
