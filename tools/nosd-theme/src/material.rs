#![forbid(unsafe_code)]

//! Material Design 3 color schemes from a source color.
//! Mirrors Scripts/python/src/theming/lib/material.py (matugen-style schemes).
//!
//! Scheme dicts are ordered `Vec`s so serialized output keeps Python's
//! dict-insertion order.

use crate::color::py_mod;
use crate::hct::{Hct, TemperatureCache, TonalPalette, fix_if_disliked};

pub type Scheme = Vec<(String, String)>;

fn tones(dark: bool, pairs: &[(&str, i64)]) -> Vec<(String, i64)> {
    let _ = dark;
    pairs.iter().map(|(k, v)| (k.to_string(), *v)).collect()
}

fn dark_tones() -> Vec<(String, i64)> {
    tones(true, &[
        ("primary", 80), ("on_primary", 20), ("primary_container", 30), ("on_primary_container", 90),
        ("secondary", 80), ("on_secondary", 20), ("secondary_container", 30), ("on_secondary_container", 90),
        ("tertiary", 80), ("on_tertiary", 20), ("tertiary_container", 30), ("on_tertiary_container", 90),
        ("error", 80), ("on_error", 20), ("error_container", 30), ("on_error_container", 90),
        ("surface", 6), ("on_surface", 90), ("surface_variant", 30), ("on_surface_variant", 80),
        ("surface_container_lowest", 4), ("surface_container_low", 10), ("surface_container", 12),
        ("surface_container_high", 17), ("surface_container_highest", 22),
        ("outline", 60), ("outline_variant", 30), ("shadow", 0), ("scrim", 0),
        ("inverse_surface", 90), ("inverse_on_surface", 20), ("inverse_primary", 40),
    ])
}

fn light_tones() -> Vec<(String, i64)> {
    tones(false, &[
        ("primary", 40), ("on_primary", 100), ("primary_container", 90), ("on_primary_container", 10),
        ("secondary", 40), ("on_secondary", 100), ("secondary_container", 90), ("on_secondary_container", 10),
        ("tertiary", 40), ("on_tertiary", 100), ("tertiary_container", 90), ("on_tertiary_container", 10),
        ("error", 40), ("on_error", 100), ("error_container", 90), ("on_error_container", 10),
        ("surface", 98), ("on_surface", 10), ("surface_variant", 90), ("on_surface_variant", 30),
        ("surface_container_lowest", 100), ("surface_container_low", 96), ("surface_container", 94),
        ("surface_container_high", 92), ("surface_container_highest", 90),
        ("outline", 50), ("outline_variant", 80), ("shadow", 0), ("scrim", 0),
        ("inverse_surface", 20), ("inverse_on_surface", 95), ("inverse_primary", 80),
    ])
}

fn apply_overrides(mut base: Vec<(String, i64)>, over: &[(&str, i64)]) -> Vec<(String, i64)> {
    for (k, v) in over {
        if let Some(slot) = base.iter_mut().find(|(name, _)| name == k) {
            slot.1 = *v;
        }
    }
    base
}

fn monochrome_dark_tones() -> Vec<(String, i64)> {
    apply_overrides(dark_tones(), &[
        ("primary", 100), ("on_primary", 10), ("primary_container", 85), ("on_primary_container", 0),
        ("tertiary", 90), ("on_tertiary", 10), ("tertiary_container", 60), ("on_tertiary_container", 0),
        ("secondary_container", 30),
    ])
}

fn monochrome_light_tones() -> Vec<(String, i64)> {
    apply_overrides(light_tones(), &[
        ("primary", 0), ("on_primary", 90), ("primary_container", 25), ("on_primary_container", 100),
        ("tertiary", 25), ("on_tertiary", 90), ("tertiary_container", 49), ("on_tertiary_container", 100),
        ("secondary_container", 90),
    ])
}

pub struct Palettes {
    pub primary: TonalPalette,
    pub secondary: TonalPalette,
    pub tertiary: TonalPalette,
    pub neutral: TonalPalette,
    pub neutral_variant: TonalPalette,
    pub error: TonalPalette,
}

impl Palettes {
    fn generate(&mut self, is_dark: bool, mono: bool) -> Scheme {
        let tones = if mono {
            if is_dark { monochrome_dark_tones() } else { monochrome_light_tones() }
        } else if is_dark {
            dark_tones()
        } else {
            light_tones()
        };
        let t = |name: &str| tones.iter().find(|(n, _)| *n == name).unwrap().1;
        let mut s: Scheme = Vec::new();
        let mut push = |name: &str, pal: &mut TonalPalette, tone: i64| {
            s.push((name.to_string(), pal.get_hex(tone)));
        };
        push("primary", &mut self.primary, t("primary"));
        push("on_primary", &mut self.primary, t("on_primary"));
        push("primary_container", &mut self.primary, t("primary_container"));
        push("on_primary_container", &mut self.primary, t("on_primary_container"));
        push("surface_tint", &mut self.primary, t("primary"));
        push("secondary", &mut self.secondary, t("secondary"));
        push("on_secondary", &mut self.secondary, t("on_secondary"));
        push("secondary_container", &mut self.secondary, t("secondary_container"));
        push("on_secondary_container", &mut self.secondary, t("on_secondary_container"));
        push("tertiary", &mut self.tertiary, t("tertiary"));
        push("on_tertiary", &mut self.tertiary, t("on_tertiary"));
        push("tertiary_container", &mut self.tertiary, t("tertiary_container"));
        push("on_tertiary_container", &mut self.tertiary, t("on_tertiary_container"));
        push("error", &mut self.error, t("error"));
        push("on_error", &mut self.error, t("on_error"));
        push("error_container", &mut self.error, t("error_container"));
        push("on_error_container", &mut self.error, t("on_error_container"));
        push("surface", &mut self.neutral, t("surface"));
        push("on_surface", &mut self.neutral, t("on_surface"));
        push("surface_variant", &mut self.neutral_variant, t("surface_variant"));
        push("on_surface_variant", &mut self.neutral_variant, t("on_surface_variant"));
        push("surface_container_lowest", &mut self.neutral, t("surface_container_lowest"));
        push("surface_container_low", &mut self.neutral, t("surface_container_low"));
        push("surface_container", &mut self.neutral, t("surface_container"));
        push("surface_container_high", &mut self.neutral, t("surface_container_high"));
        push("surface_container_highest", &mut self.neutral, t("surface_container_highest"));
        push("outline", &mut self.neutral_variant, t("outline"));
        push("outline_variant", &mut self.neutral_variant, t("outline_variant"));
        push("shadow", &mut self.neutral, t("shadow"));
        push("scrim", &mut self.neutral, t("scrim"));
        push("inverse_surface", &mut self.neutral, t("inverse_surface"));
        push("inverse_on_surface", &mut self.neutral, t("inverse_on_surface"));
        push("inverse_primary", &mut self.primary, t("inverse_primary"));
        push("background", &mut self.neutral, t("surface"));
        push("on_background", &mut self.neutral, t("on_surface"));
        if mono {
            push("surface_dim", &mut self.neutral, t("surface"));
            let highest5 = t("surface_container_highest") + 5;
            push("surface_bright", &mut self.neutral, highest5);
        } else if is_dark {
            push("surface_dim", &mut self.neutral, 6);
            push("surface_bright", &mut self.neutral, 24);
        } else {
            push("surface_dim", &mut self.neutral, 87);
            push("surface_bright", &mut self.neutral, 98);
        }
        for fixed in ["primary", "secondary", "tertiary"] {
            let pal = match fixed {
                "primary" => &mut self.primary,
                "secondary" => &mut self.secondary,
                _ => &mut self.tertiary,
            };
            push(&format!("{fixed}_fixed"), pal, 90);
            push(&format!("{fixed}_fixed_dim"), pal, 80);
            push(&format!("on_{fixed}_fixed"), pal, 10);
            push(&format!("on_{fixed}_fixed_variant"), pal, 30);
        }
        s
    }
}

fn error_palette() -> TonalPalette {
    TonalPalette::new(25.0, 84.0)
}

pub fn tonal_spot(source: Hct) -> Palettes {
    Palettes {
        primary: TonalPalette::new(source.hue, 48.0),
        secondary: TonalPalette::new(source.hue, 16.0),
        tertiary: TonalPalette::new(py_mod(source.hue + 60.0, 360.0), 24.0),
        neutral: TonalPalette::new(source.hue, 4.0),
        neutral_variant: TonalPalette::new(source.hue, 8.0),
        error: error_palette(),
    }
}

pub fn fruit_salad(source: Hct) -> Palettes {
    let rotated = py_mod(source.hue - 50.0, 360.0);
    Palettes {
        primary: TonalPalette::new(rotated, 48.0),
        secondary: TonalPalette::new(rotated, 36.0),
        tertiary: TonalPalette::new(source.hue, 36.0),
        neutral: TonalPalette::new(source.hue, 10.0),
        neutral_variant: TonalPalette::new(source.hue, 16.0),
        error: error_palette(),
    }
}

pub fn rainbow(source: Hct) -> Palettes {
    Palettes {
        primary: TonalPalette::new(source.hue, 48.0),
        secondary: TonalPalette::new(source.hue, 16.0),
        tertiary: TonalPalette::new(py_mod(source.hue + 60.0, 360.0), 24.0),
        neutral: TonalPalette::new(0.0, 0.0),
        neutral_variant: TonalPalette::new(0.0, 0.0),
        error: error_palette(),
    }
}

pub fn content(source: Hct) -> Palettes {
    let secondary_chroma = (source.chroma - 32.0).max(source.chroma * 0.5);
    let mut cache = TemperatureCache::new(source);
    let analogous = cache.analogous(Some(3), Some(6));
    let tertiary = TonalPalette::from_hct(fix_if_disliked(*analogous.last().unwrap()));
    Palettes {
        primary: TonalPalette::new(source.hue, source.chroma),
        secondary: TonalPalette::new(source.hue, secondary_chroma),
        tertiary,
        neutral: TonalPalette::new(source.hue, source.chroma / 8.0),
        neutral_variant: TonalPalette::new(source.hue, source.chroma / 8.0 + 4.0),
        error: error_palette(),
    }
}

pub fn monochrome(source: Hct) -> Palettes {
    Palettes {
        primary: TonalPalette::new(source.hue, 0.0),
        secondary: TonalPalette::new(source.hue, 0.0),
        tertiary: TonalPalette::new(source.hue, 0.0),
        neutral: TonalPalette::new(source.hue, 0.0),
        neutral_variant: TonalPalette::new(source.hue, 0.0),
        error: error_palette(),
    }
}

pub fn scheme_by_name(name: &str, source: Hct) -> Option<Palettes> {
    match name {
        "tonalspot" | "tonal-spot" => Some(tonal_spot(source)),
        "fruitsalad" | "fruit-salad" => Some(fruit_salad(source)),
        "rainbow" => Some(rainbow(source)),
        "content" => Some(content(source)),
        "monochrome" => Some(monochrome(source)),
        _ => None,
    }
}

pub fn dark_scheme(pal: &mut Palettes, name: &str) -> Scheme {
    pal.generate(true, name == "monochrome")
}

pub fn light_scheme(pal: &mut Palettes, name: &str) -> Scheme {
    pal.generate(false, name == "monochrome")
}

pub fn harmonize_color(design: Hct, source: Hct, amount: f64) -> Hct {
    let diff = hue_difference(source.hue, design.hue);
    let mut rotation = diff * amount;
    if rotation > 15.0 {
        rotation = 15.0;
    }
    if shorter_rotation(source.hue, design.hue) < 0.0 {
        rotation = -rotation;
    }
    Hct::new(py_mod(design.hue + rotation, 360.0), design.chroma, design.tone)
}

fn hue_difference(h1: f64, h2: f64) -> f64 {
    let diff = (h1 - h2).abs();
    diff.min(360.0 - diff)
}

fn shorter_rotation(from_hue: f64, to_hue: f64) -> f64 {
    let diff = to_hue - from_hue;
    if diff > 180.0 {
        return diff - 360.0;
    }
    if diff < -180.0 {
        return diff + 360.0;
    }
    diff
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::hct::Hct as H;

    fn source() -> Hct {
        H::from_rgb(255, 85, 0)
    }

    fn scheme_json(s: &Scheme) -> String {
        let parts: Vec<String> = s.iter().map(|(k, v)| format!("\"{k}\": \"{v}\"")).collect();
        format!("{{{}}}", parts.join(", "))
    }

    #[test]
    fn dark_light_key_order_and_count() {
        let mut p = tonal_spot(source());
        let dark = dark_scheme(&mut p, "tonalspot");
        let mut p = tonal_spot(source());
        let light = light_scheme(&mut p, "tonalspot");
        assert_eq!(dark.len(), 49);
        assert_eq!(light.len(), 49);
        assert_eq!(dark[0].0, "primary");
        assert_eq!(dark[48].0, "on_tertiary_fixed_variant");
        assert!(dark.iter().map(|(k, _)| k).eq(light.iter().map(|(k, _)| k)));
    }

    #[test]
    fn monochrome_differs() {
        let mut p = monochrome(source());
        let dark = dark_scheme(&mut p, "monochrome");
        assert_eq!(dark.len(), 49);
        let primary = dark.iter().find(|(k, _)| k == "primary").unwrap().1.clone();
        assert_eq!(primary, "#ffffff");
    }

    #[test]
    fn full_scheme_matches_python() {
        // Oracle: SchemeTonalSpot.from_hex('#ff5500').get_dark_scheme() etc.
        let mut p = tonal_spot(H::from_rgb(255, 85, 0));
        assert_eq!(
            scheme_json(&dark_scheme(&mut p, "tonalspot")),
            "{\"primary\": \"#ffb59c\", \"on_primary\": \"#5c1900\", \"primary_container\": \"#7c2e0f\", \"on_primary_container\": \"#ffdbcf\", \"surface_tint\": \"#ffb59c\", \"secondary\": \"#e7bdb0\", \"on_secondary\": \"#442a21\", \"secondary_container\": \"#5d4036\", \"on_secondary_container\": \"#ffdbcf\", \"tertiary\": \"#d6c68d\", \"on_tertiary\": \"#393005\", \"tertiary_container\": \"#51461a\", \"on_tertiary_container\": \"#f3e2a7\", \"error\": \"#ffb4ab\", \"on_error\": \"#690005\", \"error_container\": \"#93000a\", \"on_error_container\": \"#ffdad6\", \"surface\": \"#181210\", \"on_surface\": \"#ede0dc\", \"surface_variant\": \"#53433e\", \"on_surface_variant\": \"#d8c2bb\", \"surface_container_lowest\": \"#120d0b\", \"surface_container_low\": \"#201a18\", \"surface_container\": \"#251e1c\", \"surface_container_high\": \"#2f2826\", \"surface_container_highest\": \"#3b3331\", \"outline\": \"#a08d87\", \"outline_variant\": \"#53433e\", \"shadow\": \"#000000\", \"scrim\": \"#000000\", \"inverse_surface\": \"#ede0dc\", \"inverse_on_surface\": \"#362f2d\", \"inverse_primary\": \"#9a4525\", \"background\": \"#181210\", \"on_background\": \"#ede0dc\", \"surface_dim\": \"#181210\", \"surface_bright\": \"#3f3835\", \"primary_fixed\": \"#ffdbcf\", \"primary_fixed_dim\": \"#ffb59c\", \"on_primary_fixed\": \"#390c00\", \"on_primary_fixed_variant\": \"#7c2e0f\", \"secondary_fixed\": \"#ffdbcf\", \"secondary_fixed_dim\": \"#e7bdb0\", \"on_secondary_fixed\": \"#2c160e\", \"on_secondary_fixed_variant\": \"#5d4036\", \"tertiary_fixed\": \"#f3e2a7\", \"tertiary_fixed_dim\": \"#d6c68d\", \"on_tertiary_fixed\": \"#221b00\", \"on_tertiary_fixed_variant\": \"#51461a\"}"
        );
        let mut p = content(H::from_rgb(255, 85, 0));
        assert_eq!(
            scheme_json(&dark_scheme(&mut p, "content")),
            "{\"primary\": \"#ffb59c\", \"on_primary\": \"#5c1900\", \"primary_container\": \"#822700\", \"on_primary_container\": \"#ffdbcf\", \"surface_tint\": \"#ffb59c\", \"secondary\": \"#ffb59c\", \"on_secondary\": \"#5c1900\", \"secondary_container\": \"#812903\", \"on_secondary_container\": \"#ffdbcf\", \"tertiary\": \"#ffb94e\", \"on_tertiary\": \"#452b00\", \"tertiary_container\": \"#624000\", \"on_tertiary_container\": \"#ffddb2\", \"error\": \"#ffb4ab\", \"on_error\": \"#690005\", \"error_container\": \"#93000a\", \"on_error_container\": \"#ffdad6\", \"surface\": \"#1e100b\", \"on_surface\": \"#fbdcd3\", \"surface_variant\": \"#5c4037\", \"on_surface_variant\": \"#e5beb2\", \"surface_container_lowest\": \"#190b06\", \"surface_container_low\": \"#281812\", \"surface_container\": \"#2c1c16\", \"surface_container_high\": \"#372620\", \"surface_container_highest\": \"#43302a\", \"outline\": \"#ac897e\", \"outline_variant\": \"#5c4037\", \"shadow\": \"#000000\", \"scrim\": \"#000000\", \"inverse_surface\": \"#fbdcd3\", \"inverse_on_surface\": \"#3e2c26\", \"inverse_primary\": \"#aa3600\", \"background\": \"#1e100b\", \"on_background\": \"#fbdcd3\", \"surface_dim\": \"#1e100b\", \"surface_bright\": \"#48352e\", \"primary_fixed\": \"#ffdbcf\", \"primary_fixed_dim\": \"#ffb59c\", \"on_primary_fixed\": \"#390c00\", \"on_primary_fixed_variant\": \"#822700\", \"secondary_fixed\": \"#ffdbcf\", \"secondary_fixed_dim\": \"#ffb59c\", \"on_secondary_fixed\": \"#390c00\", \"on_secondary_fixed_variant\": \"#812903\", \"tertiary_fixed\": \"#ffddb2\", \"tertiary_fixed_dim\": \"#ffb94e\", \"on_tertiary_fixed\": \"#291800\", \"on_tertiary_fixed_variant\": \"#624000\"}"
        );
        let mut p = monochrome(H::from_rgb(255, 85, 0));
        assert_eq!(
            scheme_json(&dark_scheme(&mut p, "monochrome")),
            "{\"primary\": \"#ffffff\", \"on_primary\": \"#1b1b1b\", \"primary_container\": \"#d4d4d4\", \"on_primary_container\": \"#000000\", \"surface_tint\": \"#ffffff\", \"secondary\": \"#c6c6c6\", \"on_secondary\": \"#303030\", \"secondary_container\": \"#474747\", \"on_secondary_container\": \"#e2e2e2\", \"tertiary\": \"#e2e2e2\", \"on_tertiary\": \"#1b1b1b\", \"tertiary_container\": \"#919191\", \"on_tertiary_container\": \"#000000\", \"error\": \"#ffb4ab\", \"on_error\": \"#690005\", \"error_container\": \"#93000a\", \"on_error_container\": \"#ffdad6\", \"surface\": \"#131313\", \"on_surface\": \"#e2e2e2\", \"surface_variant\": \"#474747\", \"on_surface_variant\": \"#c6c6c6\", \"surface_container_lowest\": \"#0e0e0e\", \"surface_container_low\": \"#1b1b1b\", \"surface_container\": \"#1f1f1f\", \"surface_container_high\": \"#2a2a2a\", \"surface_container_highest\": \"#353535\", \"outline\": \"#919191\", \"outline_variant\": \"#474747\", \"shadow\": \"#000000\", \"scrim\": \"#000000\", \"inverse_surface\": \"#e2e2e2\", \"inverse_on_surface\": \"#303030\", \"inverse_primary\": \"#5e5e5e\", \"background\": \"#131313\", \"on_background\": \"#e2e2e2\", \"surface_dim\": \"#131313\", \"surface_bright\": \"#404040\", \"primary_fixed\": \"#e2e2e2\", \"primary_fixed_dim\": \"#c6c6c6\", \"on_primary_fixed\": \"#1b1b1b\", \"on_primary_fixed_variant\": \"#474747\", \"secondary_fixed\": \"#e2e2e2\", \"secondary_fixed_dim\": \"#c6c6c6\", \"on_secondary_fixed\": \"#1b1b1b\", \"on_secondary_fixed_variant\": \"#474747\", \"tertiary_fixed\": \"#e2e2e2\", \"tertiary_fixed_dim\": \"#c6c6c6\", \"on_tertiary_fixed\": \"#1b1b1b\", \"on_tertiary_fixed_variant\": \"#474747\"}"
        );
    }

    #[test]
    fn harmonize_caps_rotation() {
        let d = H::new(0.0, 40.0, 60.0);
        let s = H::new(200.0, 40.0, 60.0);
        let out = harmonize_color(d, s, 0.5);
        assert!((out.hue - 15.0).abs() < 1e-9);
        assert_eq!(out.chroma, 40.0);
        assert_eq!(out.tone, 60.0);
    }
}
