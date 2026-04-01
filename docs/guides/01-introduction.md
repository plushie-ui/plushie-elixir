# Introduction

## What is Plushie?

Plushie is a native desktop GUI platform with SDKs for multiple languages.
This guide covers the Elixir SDK.

When you build an app with Plushie, you get real native windows, not
Electron, not a web view. Your application is an Elixir process that owns
all the state. A separate Rust binary handles rendering, input, and platform
integration.

The renderer is built on [Iced](https://github.com/iced-rs/iced), a mature
cross-platform GUI toolkit for Rust. It provides GPU-accelerated rendering,
a software fallback for headless environments, and full accessibility support
including keyboard navigation and screen reader integration. You never
interact with Iced directly. Plushie handles the communication, and you can
write everything in Elixir.

## The Elm Architecture

Plushie follows the Elm architecture, a pattern for building UIs around
one-way data flow. If you have used Elm, Redux, or LiveView, the shape will
feel familiar. It is the same model/update/view cycle, just running on the
desktop instead of the browser.

There are three pieces:

**Model** - your application state. It can be anything: a map, a struct, a
tuple, a single integer. Plushie does not impose a schema. Whatever your
`init/1` callback returns becomes the initial model.

**Update** - a function that receives the current model and an event, then
returns the next model. Events come from user interaction (a button click, a
key press), from the system (a window resized, a timer fired), or from your
own async work. The update function is where all state transitions happen.

**View** - a function that takes the current model and returns a UI tree
describing what should be on screen. The runtime calls `view/1` after every
successful update. You never mutate the UI directly; you return a description
of what the screen should look like based on the current state.

The cycle looks like this:

    event -> update -> new model -> view -> UI tree -> render

This is the entire control flow. Events go in, state comes out, the view
reflects it. There is no two-way binding and no hidden mutation. When
something looks wrong on screen, you look at the model. When the model is
wrong, you look at the event that changed it. Every bug has a short trail.

Plushie also supports **subscriptions**, declarative specs for ongoing
event sources like timers, keyboard shortcuts, and window events. Your app
declares which subscriptions are active based on the current model, and the
runtime starts and stops them automatically.

This architecture makes your application predictable and testable. You can
test your entire UI through the real renderer binary (clicking buttons,
typing text, asserting on screen content) without mocking anything.

## How it works

Your Elixir application and the renderer run as two OS processes that
exchange messages over stdio by default, though other transports are
available for remote and embedded scenarios.

Your application builds UI trees using a DSL. The runtime manages the model
and runs the update/view cycle.
When the view produces a new tree, the runtime diffs it against the previous
one and sends only the changes to the renderer over a wire protocol
(MessagePack by default, with a JSON option for debugging).

The renderer receives patches, updates its internal widget tree, and
renders frames. When the user interacts with the UI (clicking a button,
typing in an input, resizing a window), the renderer sends events back
over the same connection. The runtime decodes them and feeds them into
your `update/2` callback, and the cycle continues.

The two-process split gives you resilience. If the renderer crashes, Plushie
restarts it and re-syncs your application state. Your model is never lost.
If your application code raises an exception, the runtime catches it, reverts
to the previous state, and logs the error. Neither process can take the other
down.

Because the two processes communicate over a byte stream, they do not need
to run on the same machine. Your Elixir application can run on a server or
embedded device with no display and no GPU, just the BEAM. The renderer
runs wherever there is a screen. This is how you build desktop UIs for
headless infrastructure, remote sessions over SSH, or IoT devices.

## What you can build

Plushie is a general-purpose desktop toolkit:

- **Desktop tools and utilities** - file managers, text editors, system
  monitors, anything you would reach for a native toolkit for.
- **Dashboards and data visualization** - connect to your Elixir backend
  directly, no API layer needed.
- **Creative applications** - the canvas system supports custom 2D drawing
  with shapes, paths, transforms, and interactive elements.
- **Multi-window applications** - your `view/1` can return multiple windows,
  each with its own layout, managed from a single model.
- **Reusable widget libraries** - compose existing widgets in pure Elixir,
  draw fully custom visuals with the canvas (including click, hover, drag,
  and keyboard interaction), or write Rust-backed native widgets when you
  need custom GPU rendering.
- **Remote rendering** - run your logic on a server or embedded device and
  render on a local display over SSH, as described above.

## What we will build in this guide

Throughout these chapters, we will build **Plushie Pad**, a live widget
editor for experimenting with the Plushie API.

The finished application has two panes. On the left, you write Plushie widget
code. On the right, you see it rendered in real time. An event log at the
bottom shows every event that fires as you interact with the rendered output.

Each chapter adds a feature to the pad: events, layout, styling, animation,
subscriptions, canvas drawing, custom widgets, testing, and more. By the
final chapter, you will have a fully-featured editor that doubles as a
personal playground for trying out any part of the API.

Plushie supports hot code reloading. As you work through the guide, keep
the pad running. Every change you make shows up instantly. Each chapter
adds a new capability, and you will see it appear the moment you save.

Let's get started.

---

Next: [Getting Started](02-getting-started.md)
