# Upstream issues

Issues where the right fix is in a dependency, or where current behavior
is blocked by dependency behavior. Track them here rather than adding
local workarounds.

Format per entry:

- Title
- Which dependency causes the limitation
- What the limitation is
- Any local workaround currently in place
- What the upstream fix would look like

## Window resize increments cannot be cleared through nil payload values

Dependency: `plushie-rust`

The Elixir command `Plushie.Command.Window.set_resize_increments/3`
documents `nil, nil` as the clear operation and sends those values in
the window-op payload. The Rust deserializer currently reads resize
increment fields through numeric extraction with a `0.0` fallback, then
the renderer always applies `Some(Size::new(width, height))`. JSON null
therefore becomes `0.0` instead of clearing the constraint.

Local workaround: none in plushie-elixir without changing the shared
wire shape. The SDK now validates that resize increments are either
numeric width and height values or both nil, but the nil clear path still
needs renderer support.

Upstream fix: represent resize increments as optional dimensions in the
Rust operation model, or add a dedicated clear operation in the protocol
and renderer dispatch.

## Overlay width is exposed by host SDKs but ignored by the renderer

Dependency: `plushie-rust`

The Elixir, TypeScript, Gleam, and Ruby host SDKs expose an overlay
`width` prop and encode it onto the overlay node. The Rust overlay
widget currently extracts `position`, `gap`, `offset_x`, `offset_y`,
`align`, and `flip`, but it does not extract or apply `width`. Setting
overlay width in a host SDK therefore has no renderer effect.

Local workaround: size the overlay content child, or place the content
inside a container with the desired width.

Upstream fix: either apply the `width` prop in the Rust overlay widget
or route a cross-SDK parity change that removes the field from the host
SDK overlay APIs.
