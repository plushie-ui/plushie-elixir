fn main() -> iced::Result {
    julep_bin::run(julep_core::app::JulepAppBuilder::new())
}
