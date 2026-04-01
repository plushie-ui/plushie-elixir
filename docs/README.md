# Documentation

## Guides

Sequential chapters that build on each other. Start here if you're
new to Plushie.

1. [Introduction](guides/01-introduction.md) - what Plushie is and how it works
2. [Getting Started](guides/02-getting-started.md) - installation, binary setup, first run
3. [Your First App](guides/03-your-first-app.md) - building a counter with the Elm architecture
4. [The Development Loop](guides/04-the-development-loop.md) - hot reload, IEx, debugging
5. [Events](guides/05-events.md) - widget events, keyboard, mouse, pattern matching
6. [Lists and Inputs](guides/06-lists-and-inputs.md) - dynamic lists, text inputs, forms
7. [Layout](guides/07-layout.md) - rows, columns, containers, responsive sizing
8. [Styling](guides/08-styling.md) - themes, colors, fonts, per-widget style overrides
9. [Animation and Transitions](guides/09-animation.md) - transitions, springs, tweens, easing
10. [Subscriptions](guides/10-subscriptions.md) - timers, global key/mouse events, window events
11. [Async and Effects](guides/11-async-and-effects.md) - async tasks, streams, platform effects
12. [Canvas](guides/12-canvas.md) - shapes, layers, transforms, interactive elements
13. [Custom Widgets](guides/13-custom-widgets.md) - composing widgets, canvas widgets, native Rust widgets
14. [State Management](guides/14-state-management.md) - routing, undo/redo, selection, data pipelines
15. [Testing](guides/15-testing.md) - test framework, backends, selectors, screenshots
16. [Shared State](guides/16-shared-state.md) - multi-session apps over SSH

## Reference

Lookup material organized by topic. Each page is self-contained.

- [Accessibility](reference/accessibility.md) - AccessKit integration, roles, labels, keyboard navigation
- [Animation](reference/animation.md) - transitions, springs, sequences, easing curves, animatable props
- [App Lifecycle](reference/app-lifecycle.md) - init/update/view callbacks, supervision, startup sequence
- [Built-in Widgets](reference/built-in-widgets.md) - every widget with props, events, and examples
- [Canvas](reference/canvas.md) - shapes, layers, groups, transforms, clips, gradients
- [Commands and Effects](reference/commands.md) - async, focus, scroll, window ops, platform effects
- [Composition Patterns](reference/composition-patterns.md) - reusable components, overlays, context menus, multi-window
- [Configuration](reference/configuration.md) - application config, environment variables, build settings
- [Custom Widgets](reference/custom-widgets.md) - the widget macro, props, events, state, native crates
- [DSL](reference/dsl.md) - macro internals, block forms, canvas scope, container scope
- [Events](reference/events.md) - event types, fields, bubbling, scoped ID matching
- [Mix Tasks](reference/mix-tasks.md) - build, download, gui, inspect, script, replay
- [Scoped IDs](reference/scoped-ids.md) - ID scoping rules, scope matching, command paths
- [Subscriptions](reference/subscriptions.md) - timer, keyboard, mouse, window, custom subscriptions
- [Testing](reference/testing.md) - test case setup, helpers, backends, screenshots, CI
- [Themes and Styling](reference/themes-and-styling.md) - built-in themes, custom palettes, style maps
- [Windows and Layout](reference/windows-and-layout.md) - window props, sizing, pane grids, multi-window
- [Wire Protocol](reference/wire-protocol.md) - MessagePack/JSON framing, message types, transport modes

## Other resources

- [Examples](https://github.com/plushie-ui/plushie-elixir/tree/main/examples) - example apps included in the repo
- [Changelog](changelog.html) - version history and migration notes
- [Demo apps](https://github.com/plushie-ui/plushie-demos/tree/main/elixir) - multi-file projects with custom widgets and real scaffolding
