use iced::Theme;
use serde_json::Value;

/// Resolve a JSON value into an iced Theme.
///
/// Accepts a string name (case-insensitive, underscored) or falls back to Dark.
/// An object value is reserved for future custom palette support.
pub fn resolve_theme(value: &Value) -> Theme {
    match value {
        Value::String(s) => match s.to_ascii_lowercase().as_str() {
            "light" => Theme::Light,
            "dark" => Theme::Dark,
            "dracula" => Theme::Dracula,
            "nord" => Theme::Nord,
            "solarized_light" => Theme::SolarizedLight,
            "solarized_dark" => Theme::SolarizedDark,
            "gruvbox_light" => Theme::GruvboxLight,
            "gruvbox_dark" => Theme::GruvboxDark,
            "catppuccin_latte" => Theme::CatppuccinLatte,
            "catppuccin_frappe" => Theme::CatppuccinFrappe,
            "catppuccin_macchiato" => Theme::CatppuccinMacchiato,
            "catppuccin_mocha" => Theme::CatppuccinMocha,
            "tokyo_night" => Theme::TokyoNight,
            "tokyo_night_storm" => Theme::TokyoNightStorm,
            "tokyo_night_light" => Theme::TokyoNightLight,
            "kanagawa_wave" => Theme::KanagawaWave,
            "kanagawa_dragon" => Theme::KanagawaDragon,
            "kanagawa_lotus" => Theme::KanagawaLotus,
            "moonfly" => Theme::Moonfly,
            "nightfly" => Theme::Nightfly,
            "oxocarbon" => Theme::Oxocarbon,
            "ferra" => Theme::Ferra,
            _ => Theme::Dark,
        },
        Value::Object(_map) => {
            // Custom palette support reserved for future implementation.
            Theme::Dark
        }
        _ => Theme::Dark,
    }
}
