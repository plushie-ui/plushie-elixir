defmodule Julep.Extension do
  @moduledoc """
  Behaviour for native Rust widget extensions.

  Implementing this behaviour allows a package to register a Rust crate
  that provides custom widget rendering via the `WidgetExtension` trait.

  ## Callbacks

  - `native_crate/0` -- path to the Rust crate relative to the package root.
  - `rust_constructor/0` -- full Rust expression that constructs the extension,
    pasted into the generated `main.rs` as `Box::new(<expression>)`.
  - `type_names/0` -- list of node type strings this extension handles.
    Used for compile-time collision detection.

  ## Example

      defmodule MyTerminal.Extension do
        @behaviour Julep.Extension

        @impl true
        def native_crate, do: "native/my_terminal"

        @impl true
        def rust_constructor, do: "my_terminal::TerminalExtension::new()"

        @impl true
        def type_names, do: ["terminal"]
      end
  """

  @doc "Path to the Rust crate relative to the package root."
  @callback native_crate() :: String.t()

  @doc "Full Rust constructor expression for the extension."
  @callback rust_constructor() :: String.t()

  @doc "Node type strings this extension handles."
  @callback type_names() :: [String.t()]
end
