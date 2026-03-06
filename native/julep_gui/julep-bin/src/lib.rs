#![deny(warnings)]

#[cfg(feature = "headless")]
mod headless;
mod test_mode;

mod renderer;

/// Entry point for the julep renderer.
///
/// Extension packages create a `JulepAppBuilder`, register their extensions,
/// and pass it here. The default `main.rs` simply passes an empty builder.
pub fn run(builder: julep_core::app::JulepAppBuilder) -> iced::Result {
    renderer::run(builder)
}
