# Introduction

## What is Plushie?

Plushie is a native desktop GUI platform with SDKs for multiple languages
including Elixir, Gleam, Python, Ruby, and TypeScript. This guide covers
the Elixir SDK.

When you build an app with Plushie, you get real native windows -- not a
browser engine wrapped in a desktop shell, not Electron, not a web view.
Your application is an Elixir process that owns all the state. A separate
Rust binary handles rendering, input, and platform integration.

The renderer is built on [iced](https://github.com/iced-rs/iced), a mature
cross-platform GUI toolkit for Rust. It provides GPU-accelerated rendering,
a software fallback for headless environments, and full accessibility support
including keyboard navigation and screen reader integration. You never
interact with iced directly. Plushie handles the communication, and you
write Elixir.

## The Elm Architecture

Plushie follows the Elm architecture, a pattern for building UIs around
one-way data flow. If you have used LiveView, the shape will feel familiar --
the same model/update/view cycle, just running on the desktop instead of the
browser.

There are three pieces:

**Model** -- your application state. It can be anything: a map, a struct, a
tuple, a single integer. Plushie does not impose a schema. Whatever your
`init/1` callback returns becomes the initial model.

**Update** -- a function that receives the current model and an event, then
returns the next model. Events come from user interaction (a button click, a
key press), from the system (a window resized, a timer fired), or from your
own async work. The update function is where all state transitions happen.

**View** -- a function that takes the current model and returns a UI tree
describing what should be on screen. The runtime calls `view/1` after every
successful update. You never mutate the UI directly; you describe it as a
function of state.

The cycle looks like this:

    event -> update -> new model -> view -> UI tree -> render

This is the entire control flow. Events go in, state comes out, the view
reflects it. There is no two-way binding, no observable, no hidden mutation.
When something looks wrong on screen, you look at the model. When the model
is wrong, you look at the event that changed it. Every bug has a short trail.

This matters because it makes your application predictable and testable. You
can call `update/2` directly in a test, check the returned model, and know
exactly what the UI will show -- without rendering anything.

## How it works

At a high level, Plushie runs as two OS processes talking over stdio.

Your Elixir application builds UI trees using the `Plushie.UI` DSL. The
`Plushie.Runtime` process manages the model and runs the update/view cycle.
When the view produces a new tree, the runtime diffs it against the previous
one and sends only the changes to the renderer over a wire protocol
(MessagePack by default, with a JSON option for debugging).

The renderer receives patches, updates its internal widget tree, and
renders frames. When the user interacts with the UI -- clicking a button,
typing in an input, resizing a window -- the renderer sends events back
over the same connection. The runtime decodes them and feeds them into
your `update/2` callback, and the cycle continues.

The two-process split also gives you resilience. If the renderer crashes,
Plushie restarts it automatically and re-syncs your application state --
your model is never lost. If your application code raises an exception, the
runtime catches it, reverts to the previous state, and logs the error.
Neither process can take the other down. The renderer also handles animation
interpolation locally, so transitions run at full frame rate with zero wire
traffic until they complete.

You do not need to think about any of this to use Plushie. The runtime and
bridge handle it. But knowing the shape helps when you are debugging or
reasoning about performance: Elixir never blocks on rendering, the renderer
never blocks on your logic, and only diffs cross the wire. The wire protocol
is language-agnostic (MessagePack over stdio), which is how the same
renderer powers SDKs for multiple languages.

Because the two processes communicate over a byte stream, they do not need
to run on the same machine. Your Elixir application can run on a server or
embedded device with no display server, no GPU, and no windowing dependencies
-- just the BEAM and MessagePack. The renderer runs wherever there is a
screen. This is how you build desktop UIs for headless infrastructure, IoT
devices, or remote sessions over SSH.

## What you can build

Plushie is a general-purpose desktop toolkit. Some things it is well suited
for:

- **Desktop tools and utilities** -- file managers, text editors, system
  monitors, anything you would reach for a native toolkit for.
- **Dashboards and data visualization** -- connect to your Elixir backend
  directly, no API layer needed.
- **Creative applications** -- the canvas system supports custom 2D drawing
  with shapes, paths, transforms, and interactive elements.
- **Multi-window applications** -- your `view/1` can return multiple windows,
  each with its own layout, managed from a single model.
- **Reusable widget libraries** -- build widgets in pure Elixir that compose
  existing primitives, or write Rust-backed native widgets for custom
  rendering.
- **Remote rendering** -- run your logic on a server or embedded device
  and render on a local display, as described above.

## What we will build in this guide

Throughout these chapters, we will build **Plushie Pad** -- a live widget
editor for experimenting with the Plushie API.

The finished application has two panes. On the left, you write Plushie widget
code. On the right, you see it rendered in real time. An event log at the
bottom shows every event that fires as you interact with the rendered output.

Each chapter adds a feature to the pad: file management, layout, styling,
keyboard shortcuts, persistence, canvas drawing, custom widgets, and more.
By the final chapter, you will have a fully-featured editor that doubles as
a personal playground for trying out any part of the API.

One more thing: Plushie supports hot code reloading. As you work through
the guide and edit the pad's own source code, your changes show up instantly
in the running application. The tool you are building is also the tool you
are using to build it.

Let's get started.
