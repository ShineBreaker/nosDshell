#![forbid(unsafe_code)]

//! Theme generation: Material (M3 schemes) plus wallust-style normal/muted.
//! Mirrors Scripts/python/src/theming/lib/theme.py.
//!
//! All dicts keep Python's insertion order (ordered `Vec`).

use crate::color::{Color, adjust_surface, hue_distance, shift_hue};
use crate::contrast::ensure_contrast;
use crate::hct::Hct;
use crate::material::{self, Scheme};
use crate::palette::find_error_color;

fn fallback_dark() -> Color {
    Color::new(255, 245, 155)
}
fn fallback_light() -> Color {
    Color::new(93, 101, 245)
}

fn primary_of(palette: &[Color], dark: bool) -> Color {
    if palette.is_empty() {
        if dark { fallback_dark() } else { fallback_light() }
    } else {
        palette[0]
    }
}

pub fn generate_material_dark(palette: &[Color], scheme_type: &str) -> Scheme {
    let primary = primary_of(palette, true);
    let hct = Hct::from_rgb(primary.r, primary.g, primary.b);
    let mut pal = material::scheme_by_name(scheme_type, hct).unwrap_or_else(|| material::tonal_spot(hct));
    material::dark_scheme(&mut pal, scheme_type)
}

pub fn generate_material_light(palette: &[Color], scheme_type: &str) -> Scheme {
    let primary = primary_of(palette, false);
    let hct = Hct::from_rgb(primary.r, primary.g, primary.b);
    let mut pal = material::scheme_by_name(scheme_type, hct).unwrap_or_else(|| material::tonal_spot(hct));
    material::light_scheme(&mut pal, scheme_type)
}

fn pick_secondary(primary: Color, palette: &[Color], shift: f64) -> Color {
    let (ph, _, _) = primary.to_hsl();
    if palette.len() > 1 {
        let (sec_h, _, _) = palette[1].to_hsl();
        if hue_distance(ph, sec_h) > 30.0 {
            return palette[1];
        }
    }
    shift_hue(primary, shift)
}

fn pick_tertiary(primary: Color, secondary: Color, palette: &[Color]) -> Color {
    let (ph, _, _) = primary.to_hsl();
    if palette.len() > 2 {
        let (ter_h, _, _) = palette[2].to_hsl();
        let (sec_h, _, _) = secondary.to_hsl();
        if hue_distance(ph, ter_h) > 30.0 && hue_distance(sec_h, ter_h) > 30.0 {
            return palette[2];
        }
    }
    shift_hue(primary, 60.0)
}

fn make_container_dark(base: Color) -> Color {
    let (h, s, l) = base.to_hsl();
    Color::from_hsl(h, (s + 0.15).min(1.0), (l - 0.35).max(0.15))
}

fn make_container_light(base: Color) -> Color {
    let (h, s, l) = base.to_hsl();
    Color::from_hsl(h, (s - 0.20).max(0.30), (l + 0.35).min(0.85))
}

fn make_fixed_dark(base: Color) -> (Color, Color) {
    let (h, s, _) = base.to_hsl();
    (Color::from_hsl(h, s.max(0.70), 0.85), Color::from_hsl(h, s.max(0.65), 0.75))
}

fn make_fixed_light(base: Color) -> (Color, Color) {
    let (h, s, _) = base.to_hsl();
    (Color::from_hsl(h, s.max(0.70), 0.40), Color::from_hsl(h, s.max(0.65), 0.30))
}

pub fn generate_normal_dark(palette: &[Color]) -> Scheme {
    let primary = primary_of(palette, true);
    let (primary_h, primary_s, _) = primary.to_hsl();
    let secondary = pick_secondary(primary, palette, 30.0);
    let tertiary = pick_tertiary(primary, secondary, palette);
    let error = find_error_color(palette);

    let (h, s, l) = primary.to_hsl();
    let primary_adjusted = Color::from_hsl(h, s.max(0.7), l.max(0.65));
    let (h, s, l) = secondary.to_hsl();
    let secondary_adjusted = Color::from_hsl(h, s.max(0.6), l.max(0.60));
    let (h, s, l) = tertiary.to_hsl();
    let tertiary_adjusted = Color::from_hsl(h, s.max(0.5), l.max(0.60));

    let primary_container = make_container_dark(primary_adjusted);
    let secondary_container = make_container_dark(secondary_adjusted);
    let tertiary_container = make_container_dark(tertiary_adjusted);
    let error_container = make_container_dark(error);

    let (mut surface_hue, s, _) = primary.to_hsl();
    if (160.0..=200.0).contains(&surface_hue) {
        surface_hue = (surface_hue + 10.0) % 360.0;
    }
    let cap = if surface_hue < 60.0 || surface_hue > 300.0 {
        0.35
    } else if (60.0..120.0).contains(&surface_hue) {
        0.50
    } else {
        0.90
    };
    let base_surface = Color::from_hsl(surface_hue, s.min(cap), 0.5);
    let surface = adjust_surface(base_surface, cap, 0.12);
    let surface_variant = adjust_surface(base_surface, 0.80f64.min(cap), 0.16);
    let lowest = adjust_surface(base_surface, 0.85, 0.06);
    let low = adjust_surface(base_surface, 0.85, 0.10);
    let container = adjust_surface(base_surface, 0.70, 0.20);
    let high = adjust_surface(base_surface, 0.75, 0.18);
    let highest = adjust_surface(base_surface, 0.70, 0.22);

    let (text_h, _, _) = primary.to_hsl();
    let on_surface = ensure_contrast(Color::from_hsl(text_h, 0.05, 0.95), surface, 4.5, None);
    let on_surface_variant = ensure_contrast(Color::from_hsl(text_h, 0.05, 0.70), surface_variant, 4.5, None);
    let outline = ensure_contrast(adjust_surface(primary, 0.10, 0.30), surface, 3.0, None);
    let outline_variant = ensure_contrast(adjust_surface(primary, 0.10, 0.40), surface, 3.0, None);

    let dark_fg = Color::from_hsl(primary.to_hsl().0, 0.20, 0.12);
    let on_primary = ensure_contrast(dark_fg, primary_adjusted, 7.0, None);
    let on_secondary = ensure_contrast(dark_fg, secondary_adjusted, 7.0, None);
    let on_tertiary = ensure_contrast(dark_fg, tertiary_adjusted, 7.0, None);
    let on_error = ensure_contrast(dark_fg, error, 7.0, None);

    let on_primary_container =
        ensure_contrast(Color::from_hsl(primary_h, primary_s, 0.90), primary_container, 4.5, Some(true));
    let (sec_h, sec_s, _) = secondary.to_hsl();
    let on_secondary_container =
        ensure_contrast(Color::from_hsl(sec_h, sec_s, 0.90), secondary_container, 4.5, Some(true));
    let (ter_h, ter_s, _) = tertiary.to_hsl();
    let on_tertiary_container =
        ensure_contrast(Color::from_hsl(ter_h, ter_s, 0.90), tertiary_container, 4.5, Some(true));
    let (err_h, err_s, _) = error.to_hsl();
    let on_error_container =
        ensure_contrast(Color::from_hsl(err_h, err_s, 0.90), error_container, 4.5, Some(true));

    let shadow = surface;
    let scrim = Color::new(0, 0, 0);
    let inv_h = primary.to_hsl().0;
    let inverse_surface = Color::from_hsl(inv_h, 0.08, 0.90);
    let inverse_on_surface = Color::from_hsl(inv_h, 0.05, 0.15);
    let inverse_primary = Color::from_hsl(primary_h, (primary_s * 0.8).max(0.5), 0.40);
    let background = surface;
    let on_background = on_surface;

    let (primary_fixed, primary_fixed_dim) = make_fixed_dark(primary_adjusted);
    let (secondary_fixed, secondary_fixed_dim) = make_fixed_dark(secondary_adjusted);
    let (tertiary_fixed, tertiary_fixed_dim) = make_fixed_dark(tertiary_adjusted);
    let on_primary_fixed = ensure_contrast(Color::from_hsl(primary_h, 0.15, 0.15), primary_fixed, 4.5, None);
    let on_primary_fixed_variant =
        ensure_contrast(Color::from_hsl(primary_h, 0.15, 0.20), primary_fixed_dim, 4.5, None);
    let on_secondary_fixed =
        ensure_contrast(Color::from_hsl(secondary.to_hsl().0, 0.15, 0.15), secondary_fixed, 4.5, None);
    let on_secondary_fixed_variant =
        ensure_contrast(Color::from_hsl(secondary.to_hsl().0, 0.15, 0.20), secondary_fixed_dim, 4.5, None);
    let on_tertiary_fixed =
        ensure_contrast(Color::from_hsl(tertiary.to_hsl().0, 0.15, 0.15), tertiary_fixed, 4.5, None);
    let on_tertiary_fixed_variant =
        ensure_contrast(Color::from_hsl(tertiary.to_hsl().0, 0.15, 0.20), tertiary_fixed_dim, 4.5, None);

    let surface_dim = adjust_surface(base_surface, 0.85, 0.08);
    let surface_bright = adjust_surface(base_surface, 0.75, 0.24);

    let hex = |c: Color| c.to_hex();
    vec![
        ("primary", hex(primary_adjusted)), ("on_primary", hex(on_primary)),
        ("primary_container", hex(primary_container)), ("on_primary_container", hex(on_primary_container)),
        ("primary_fixed", hex(primary_fixed)), ("primary_fixed_dim", hex(primary_fixed_dim)),
        ("on_primary_fixed", hex(on_primary_fixed)), ("on_primary_fixed_variant", hex(on_primary_fixed_variant)),
        ("surface_tint", hex(primary_adjusted)),
        ("secondary", hex(secondary_adjusted)), ("on_secondary", hex(on_secondary)),
        ("secondary_container", hex(secondary_container)), ("on_secondary_container", hex(on_secondary_container)),
        ("secondary_fixed", hex(secondary_fixed)), ("secondary_fixed_dim", hex(secondary_fixed_dim)),
        ("on_secondary_fixed", hex(on_secondary_fixed)), ("on_secondary_fixed_variant", hex(on_secondary_fixed_variant)),
        ("tertiary", hex(tertiary_adjusted)), ("on_tertiary", hex(on_tertiary)),
        ("tertiary_container", hex(tertiary_container)), ("on_tertiary_container", hex(on_tertiary_container)),
        ("tertiary_fixed", hex(tertiary_fixed)), ("tertiary_fixed_dim", hex(tertiary_fixed_dim)),
        ("on_tertiary_fixed", hex(on_tertiary_fixed)), ("on_tertiary_fixed_variant", hex(on_tertiary_fixed_variant)),
        ("error", hex(error)), ("on_error", hex(on_error)),
        ("error_container", hex(error_container)), ("on_error_container", hex(on_error_container)),
        ("surface", hex(surface)), ("on_surface", hex(on_surface)),
        ("surface_variant", hex(surface_variant)), ("on_surface_variant", hex(on_surface_variant)),
        ("surface_dim", hex(surface_dim)), ("surface_bright", hex(surface_bright)),
        ("surface_container_lowest", hex(lowest)), ("surface_container_low", hex(low)),
        ("surface_container", hex(container)),
        ("surface_container_high", hex(high)), ("surface_container_highest", hex(highest)),
        ("outline", hex(outline)), ("outline_variant", hex(outline_variant)),
        ("shadow", hex(shadow)), ("scrim", hex(scrim)),
        ("inverse_surface", hex(inverse_surface)), ("inverse_on_surface", hex(inverse_on_surface)),
        ("inverse_primary", hex(inverse_primary)),
        ("background", hex(background)), ("on_background", hex(on_background)),
    ]
    .into_iter()
    .map(|(k, v)| (k.to_string(), v))
    .collect()
}

pub fn generate_normal_light(palette: &[Color]) -> Scheme {
    let primary = primary_of(palette, false);
    let (primary_h, _, _) = primary.to_hsl();
    let secondary = pick_secondary(primary, palette, 30.0);
    let tertiary = pick_tertiary(primary, secondary, palette);
    let error = find_error_color(palette);

    let (h, s, l) = primary.to_hsl();
    let primary_adjusted = Color::from_hsl(h, s.max(0.7), l.min(0.45).max(0.25));
    let (h, s, l) = secondary.to_hsl();
    let secondary_adjusted = Color::from_hsl(h, s.max(0.6), l.min(0.40).max(0.22));
    let (h, s, l) = tertiary.to_hsl();
    let tertiary_adjusted = Color::from_hsl(h, s.max(0.5), l.min(0.35).max(0.20));

    let primary_container = make_container_light(primary_adjusted);
    let secondary_container = make_container_light(secondary_adjusted);
    let tertiary_container = make_container_light(tertiary_adjusted);
    let error_container = make_container_light(error);

    let p0 = primary_of(palette, false);
    let surface = adjust_surface(p0, 0.90, 0.90);
    let surface_variant = adjust_surface(p0, 0.80, 0.78);
    let lowest = adjust_surface(p0, 0.85, 0.96);
    let low = adjust_surface(p0, 0.85, 0.92);
    let container = adjust_surface(p0, 0.80, 0.86);
    let high = adjust_surface(p0, 0.75, 0.84);
    let highest = adjust_surface(p0, 0.70, 0.80);

    let (text_h, _, _) = p0.to_hsl();
    let on_surface = ensure_contrast(Color::from_hsl(text_h, 0.05, 0.10), surface, 4.5, None);
    let on_surface_variant = ensure_contrast(Color::from_hsl(text_h, 0.05, 0.35), surface_variant, 4.5, None);

    let light_fg = Color::from_hsl(text_h, 0.1, 0.98);
    let on_primary = ensure_contrast(light_fg, primary_adjusted, 7.0, None);
    let on_secondary = ensure_contrast(light_fg, secondary_adjusted, 7.0, None);
    let on_tertiary = ensure_contrast(light_fg, tertiary_adjusted, 7.0, None);
    let on_error = ensure_contrast(light_fg, error, 7.0, None);

    let (primary_h2, primary_s2, _) = primary.to_hsl();
    let on_primary_container =
        ensure_contrast(Color::from_hsl(primary_h2, primary_s2, 0.15), primary_container, 4.5, Some(false));
    let (sec_h, sec_s, _) = secondary.to_hsl();
    let on_secondary_container =
        ensure_contrast(Color::from_hsl(sec_h, sec_s, 0.15), secondary_container, 4.5, Some(false));
    let (ter_h, ter_s, _) = tertiary.to_hsl();
    let on_tertiary_container =
        ensure_contrast(Color::from_hsl(ter_h, ter_s, 0.15), tertiary_container, 4.5, Some(false));
    let (err_h, err_s, _) = error.to_hsl();
    let on_error_container =
        ensure_contrast(Color::from_hsl(err_h, err_s, 0.15), error_container, 4.5, Some(false));

    let (primary_fixed, primary_fixed_dim) = make_fixed_light(primary_adjusted);
    let (secondary_fixed, secondary_fixed_dim) = make_fixed_light(secondary_adjusted);
    let (tertiary_fixed, tertiary_fixed_dim) = make_fixed_light(tertiary_adjusted);
    let on_primary_fixed = ensure_contrast(Color::from_hsl(primary_h, 0.15, 0.90), primary_fixed, 4.5, None);
    let on_primary_fixed_variant =
        ensure_contrast(Color::from_hsl(primary_h, 0.15, 0.85), primary_fixed_dim, 4.5, None);
    let on_secondary_fixed =
        ensure_contrast(Color::from_hsl(secondary.to_hsl().0, 0.15, 0.90), secondary_fixed, 4.5, None);
    let on_secondary_fixed_variant =
        ensure_contrast(Color::from_hsl(secondary.to_hsl().0, 0.15, 0.85), secondary_fixed_dim, 4.5, None);
    let on_tertiary_fixed =
        ensure_contrast(Color::from_hsl(tertiary.to_hsl().0, 0.15, 0.90), tertiary_fixed, 4.5, None);
    let on_tertiary_fixed_variant =
        ensure_contrast(Color::from_hsl(tertiary.to_hsl().0, 0.15, 0.85), tertiary_fixed_dim, 4.5, None);

    let surface_dim = adjust_surface(p0, 0.85, 0.82);
    let surface_bright = adjust_surface(p0, 0.90, 0.95);

    let (surface_h, surface_s, _) = p0.to_hsl();
    let outline = ensure_contrast(
        Color::from_hsl(surface_h, (surface_s * 0.4).max(0.25), 0.65), surface, 3.0, None,
    );
    let outline_variant = ensure_contrast(
        Color::from_hsl(surface_h, (surface_s * 0.3).max(0.20), 0.75), surface, 3.0, None,
    );
    let shadow = Color::from_hsl(surface_h, (surface_s * 0.3).max(0.15), 0.80);
    let scrim = Color::new(0, 0, 0);

    let inverse_surface = Color::from_hsl(surface_h, 0.08, 0.15);
    let inverse_on_surface = Color::from_hsl(surface_h, 0.05, 0.90);
    let inverse_primary = Color::from_hsl(primary_h2, (primary_s2 * 0.8).max(0.5), 0.70);
    let background = surface;
    let on_background = on_surface;

    let hex = |c: Color| c.to_hex();
    vec![
        ("primary", hex(primary_adjusted)), ("on_primary", hex(on_primary)),
        ("primary_container", hex(primary_container)), ("on_primary_container", hex(on_primary_container)),
        ("primary_fixed", hex(primary_fixed)), ("primary_fixed_dim", hex(primary_fixed_dim)),
        ("on_primary_fixed", hex(on_primary_fixed)), ("on_primary_fixed_variant", hex(on_primary_fixed_variant)),
        ("surface_tint", hex(primary_adjusted)),
        ("secondary", hex(secondary_adjusted)), ("on_secondary", hex(on_secondary)),
        ("secondary_container", hex(secondary_container)), ("on_secondary_container", hex(on_secondary_container)),
        ("secondary_fixed", hex(secondary_fixed)), ("secondary_fixed_dim", hex(secondary_fixed_dim)),
        ("on_secondary_fixed", hex(on_secondary_fixed)), ("on_secondary_fixed_variant", hex(on_secondary_fixed_variant)),
        ("tertiary", hex(tertiary_adjusted)), ("on_tertiary", hex(on_tertiary)),
        ("tertiary_container", hex(tertiary_container)), ("on_tertiary_container", hex(on_tertiary_container)),
        ("tertiary_fixed", hex(tertiary_fixed)), ("tertiary_fixed_dim", hex(tertiary_fixed_dim)),
        ("on_tertiary_fixed", hex(on_tertiary_fixed)), ("on_tertiary_fixed_variant", hex(on_tertiary_fixed_variant)),
        ("error", hex(error)), ("on_error", hex(on_error)),
        ("error_container", hex(error_container)), ("on_error_container", hex(on_error_container)),
        ("surface", hex(surface)), ("on_surface", hex(on_surface)),
        ("surface_variant", hex(surface_variant)), ("on_surface_variant", hex(on_surface_variant)),
        ("surface_dim", hex(surface_dim)), ("surface_bright", hex(surface_bright)),
        ("surface_container_lowest", hex(lowest)), ("surface_container_low", hex(low)),
        ("surface_container", hex(container)),
        ("surface_container_high", hex(high)), ("surface_container_highest", hex(highest)),
        ("outline", hex(outline)), ("outline_variant", hex(outline_variant)),
        ("shadow", hex(shadow)), ("scrim", hex(scrim)),
        ("inverse_surface", hex(inverse_surface)), ("inverse_on_surface", hex(inverse_on_surface)),
        ("inverse_primary", hex(inverse_primary)),
        ("background", hex(background)), ("on_background", hex(on_background)),
    ]
    .into_iter()
    .map(|(k, v)| (k.to_string(), v))
    .collect()
}

pub fn generate_muted_dark(palette: &[Color]) -> Scheme {
    const MSP: f64 = 0.15;
    const MSS: f64 = 0.12;
    const MST: f64 = 0.10;
    const MSF: f64 = 0.08;
    let primary = if palette.is_empty() { Color::new(128, 128, 128) } else { palette[0] };
    let (primary_h, primary_s, _) = primary.to_hsl();
    let secondary = shift_hue(primary, 15.0);
    let tertiary = shift_hue(primary, 30.0);
    let error = find_error_color(palette);

    let (h, s, l) = primary.to_hsl();
    let primary_adjusted = Color::from_hsl(h, s.min(MSP), l.max(0.65));
    let (h, s, l) = secondary.to_hsl();
    let secondary_adjusted = Color::from_hsl(h, s.min(MSS), l.max(0.60));
    let (h, s, l) = tertiary.to_hsl();
    let tertiary_adjusted = Color::from_hsl(h, s.min(MST), l.max(0.60));

    let cont = |base: Color| {
        let (h, s, l) = base.to_hsl();
        Color::from_hsl(h, (s + 0.05).min(MSP), (l - 0.35).max(0.15))
    };
    let primary_container = cont(primary_adjusted);
    let secondary_container = cont(secondary_adjusted);
    let tertiary_container = cont(tertiary_adjusted);
    let error_container = cont(error);

    let base_surface = Color::from_hsl(primary_h, MSF, 0.5);
    let surface = adjust_surface(base_surface, MSF, 0.12);
    let surface_variant = adjust_surface(base_surface, MSF, 0.16);
    let lowest = adjust_surface(base_surface, MSF, 0.06);
    let low = adjust_surface(base_surface, MSF, 0.10);
    let container = adjust_surface(base_surface, MSF, 0.20);
    let high = adjust_surface(base_surface, MSF, 0.18);
    let highest = adjust_surface(base_surface, MSF, 0.22);

    let on_surface = ensure_contrast(Color::from_hsl(primary_h, 0.03, 0.95), surface, 4.5, None);
    let on_surface_variant =
        ensure_contrast(Color::from_hsl(primary_h, 0.03, 0.70), surface_variant, 4.5, None);
    let outline = ensure_contrast(Color::from_hsl(primary_h, 0.05, 0.30), surface, 3.0, None);
    let outline_variant = ensure_contrast(Color::from_hsl(primary_h, 0.05, 0.40), surface, 3.0, None);

    let dark_fg = Color::from_hsl(primary_h, 0.10, 0.12);
    let on_primary = ensure_contrast(dark_fg, primary_adjusted, 7.0, None);
    let on_secondary = ensure_contrast(dark_fg, secondary_adjusted, 7.0, None);
    let on_tertiary = ensure_contrast(dark_fg, tertiary_adjusted, 7.0, None);
    let on_error = ensure_contrast(dark_fg, error, 7.0, None);

    let on_primary_container =
        ensure_contrast(Color::from_hsl(primary_h, 0.05, 0.90), primary_container, 4.5, Some(true));
    let (sec_h, _, _) = secondary.to_hsl();
    let on_secondary_container =
        ensure_contrast(Color::from_hsl(sec_h, 0.05, 0.90), secondary_container, 4.5, Some(true));
    let (ter_h, _, _) = tertiary.to_hsl();
    let on_tertiary_container =
        ensure_contrast(Color::from_hsl(ter_h, 0.05, 0.90), tertiary_container, 4.5, Some(true));
    let (err_h, _, _) = error.to_hsl();
    let on_error_container =
        ensure_contrast(Color::from_hsl(err_h, 0.05, 0.90), error_container, 4.5, Some(true));

    let shadow = surface;
    let scrim = Color::new(0, 0, 0);
    let inverse_surface = Color::from_hsl(primary_h, 0.05, 0.90);
    let inverse_on_surface = Color::from_hsl(primary_h, 0.03, 0.15);
    let inverse_primary = Color::from_hsl(primary_h, (primary_s * 0.5).min(MSP), 0.40);
    let background = surface;
    let on_background = on_surface;

    let fixed = |base: Color| {
        let (h, s, _) = base.to_hsl();
        (Color::from_hsl(h, s.min(MSP), 0.85), Color::from_hsl(h, s.min(MSP), 0.75))
    };
    let (primary_fixed, primary_fixed_dim) = fixed(primary_adjusted);
    let (secondary_fixed, secondary_fixed_dim) = fixed(secondary_adjusted);
    let (tertiary_fixed, tertiary_fixed_dim) = fixed(tertiary_adjusted);
    let on_primary_fixed = ensure_contrast(Color::from_hsl(primary_h, 0.05, 0.15), primary_fixed, 4.5, None);
    let on_primary_fixed_variant =
        ensure_contrast(Color::from_hsl(primary_h, 0.05, 0.20), primary_fixed_dim, 4.5, None);
    let on_secondary_fixed =
        ensure_contrast(Color::from_hsl(sec_h, 0.05, 0.15), secondary_fixed, 4.5, None);
    let on_secondary_fixed_variant =
        ensure_contrast(Color::from_hsl(sec_h, 0.05, 0.20), secondary_fixed_dim, 4.5, None);
    let on_tertiary_fixed =
        ensure_contrast(Color::from_hsl(ter_h, 0.05, 0.15), tertiary_fixed, 4.5, None);
    let on_tertiary_fixed_variant =
        ensure_contrast(Color::from_hsl(ter_h, 0.05, 0.20), tertiary_fixed_dim, 4.5, None);

    let surface_dim = adjust_surface(base_surface, MSF, 0.08);
    let surface_bright = adjust_surface(base_surface, MSF, 0.24);

    let hex = |c: Color| c.to_hex();
    vec![
        ("primary", hex(primary_adjusted)), ("on_primary", hex(on_primary)),
        ("primary_container", hex(primary_container)), ("on_primary_container", hex(on_primary_container)),
        ("primary_fixed", hex(primary_fixed)), ("primary_fixed_dim", hex(primary_fixed_dim)),
        ("on_primary_fixed", hex(on_primary_fixed)), ("on_primary_fixed_variant", hex(on_primary_fixed_variant)),
        ("surface_tint", hex(primary_adjusted)),
        ("secondary", hex(secondary_adjusted)), ("on_secondary", hex(on_secondary)),
        ("secondary_container", hex(secondary_container)), ("on_secondary_container", hex(on_secondary_container)),
        ("secondary_fixed", hex(secondary_fixed)), ("secondary_fixed_dim", hex(secondary_fixed_dim)),
        ("on_secondary_fixed", hex(on_secondary_fixed)), ("on_secondary_fixed_variant", hex(on_secondary_fixed_variant)),
        ("tertiary", hex(tertiary_adjusted)), ("on_tertiary", hex(on_tertiary)),
        ("tertiary_container", hex(tertiary_container)), ("on_tertiary_container", hex(on_tertiary_container)),
        ("tertiary_fixed", hex(tertiary_fixed)), ("tertiary_fixed_dim", hex(tertiary_fixed_dim)),
        ("on_tertiary_fixed", hex(on_tertiary_fixed)), ("on_tertiary_fixed_variant", hex(on_tertiary_fixed_variant)),
        ("error", hex(error)), ("on_error", hex(on_error)),
        ("error_container", hex(error_container)), ("on_error_container", hex(on_error_container)),
        ("surface", hex(surface)), ("on_surface", hex(on_surface)),
        ("surface_variant", hex(surface_variant)), ("on_surface_variant", hex(on_surface_variant)),
        ("surface_dim", hex(surface_dim)), ("surface_bright", hex(surface_bright)),
        ("surface_container_lowest", hex(lowest)), ("surface_container_low", hex(low)),
        ("surface_container", hex(container)),
        ("surface_container_high", hex(high)), ("surface_container_highest", hex(highest)),
        ("outline", hex(outline)), ("outline_variant", hex(outline_variant)),
        ("shadow", hex(shadow)), ("scrim", hex(scrim)),
        ("inverse_surface", hex(inverse_surface)), ("inverse_on_surface", hex(inverse_on_surface)),
        ("inverse_primary", hex(inverse_primary)),
        ("background", hex(background)), ("on_background", hex(on_background)),
    ]
    .into_iter()
    .map(|(k, v)| (k.to_string(), v))
    .collect()
}

pub fn generate_muted_light(palette: &[Color]) -> Scheme {
    const MSP: f64 = 0.15;
    const MSS: f64 = 0.12;
    const MST: f64 = 0.10;
    const MSF: f64 = 0.08;
    let primary = if palette.is_empty() { Color::new(128, 128, 128) } else { palette[0] };
    let (primary_h, primary_s, _) = primary.to_hsl();
    let secondary = shift_hue(primary, 15.0);
    let tertiary = shift_hue(primary, 30.0);
    let error = find_error_color(palette);

    let (h, s, l) = primary.to_hsl();
    let primary_adjusted = Color::from_hsl(h, s.min(MSP), l.min(0.45));
    let (h, s, l) = secondary.to_hsl();
    let secondary_adjusted = Color::from_hsl(h, s.min(MSS), l.min(0.40));
    let (h, s, l) = tertiary.to_hsl();
    let tertiary_adjusted = Color::from_hsl(h, s.min(MST), l.min(0.35));

    let cont = |base: Color| {
        let (h, s, l) = base.to_hsl();
        Color::from_hsl(h, (s - 0.05).max(0.05), (l + 0.35).min(0.85))
    };
    let primary_container = cont(primary_adjusted);
    let secondary_container = cont(secondary_adjusted);
    let tertiary_container = cont(tertiary_adjusted);
    let error_container = cont(error);

    let surface = adjust_surface(primary, MSF, 0.90);
    let surface_variant = adjust_surface(primary, MSF, 0.78);
    let lowest = adjust_surface(primary, MSF, 0.96);
    let low = adjust_surface(primary, MSF, 0.92);
    let container = adjust_surface(primary, MSF, 0.86);
    let high = adjust_surface(primary, MSF, 0.84);
    let highest = adjust_surface(primary, MSF, 0.80);

    let on_surface = ensure_contrast(Color::from_hsl(primary_h, 0.03, 0.10), surface, 4.5, None);
    let on_surface_variant =
        ensure_contrast(Color::from_hsl(primary_h, 0.03, 0.35), surface_variant, 4.5, None);

    let light_fg = Color::from_hsl(primary_h, 0.05, 0.98);
    let on_primary = ensure_contrast(light_fg, primary_adjusted, 7.0, None);
    let on_secondary = ensure_contrast(light_fg, secondary_adjusted, 7.0, None);
    let on_tertiary = ensure_contrast(light_fg, tertiary_adjusted, 7.0, None);
    let on_error = ensure_contrast(light_fg, error, 7.0, None);

    let on_primary_container =
        ensure_contrast(Color::from_hsl(primary_h, 0.05, 0.15), primary_container, 4.5, Some(false));
    let (sec_h, _, _) = secondary.to_hsl();
    let on_secondary_container =
        ensure_contrast(Color::from_hsl(sec_h, 0.05, 0.15), secondary_container, 4.5, Some(false));
    let (ter_h, _, _) = tertiary.to_hsl();
    let on_tertiary_container =
        ensure_contrast(Color::from_hsl(ter_h, 0.05, 0.15), tertiary_container, 4.5, Some(false));
    let (err_h, _, _) = error.to_hsl();
    let on_error_container =
        ensure_contrast(Color::from_hsl(err_h, 0.05, 0.15), error_container, 4.5, Some(false));

    let fixed = |base: Color| {
        let (h, s, _) = base.to_hsl();
        (Color::from_hsl(h, s.min(MSP), 0.40), Color::from_hsl(h, s.min(MSP), 0.30))
    };
    let (primary_fixed, primary_fixed_dim) = fixed(primary_adjusted);
    let (secondary_fixed, secondary_fixed_dim) = fixed(secondary_adjusted);
    let (tertiary_fixed, tertiary_fixed_dim) = fixed(tertiary_adjusted);
    let on_primary_fixed = ensure_contrast(Color::from_hsl(primary_h, 0.05, 0.90), primary_fixed, 4.5, None);
    let on_primary_fixed_variant =
        ensure_contrast(Color::from_hsl(primary_h, 0.05, 0.85), primary_fixed_dim, 4.5, None);
    let on_secondary_fixed =
        ensure_contrast(Color::from_hsl(sec_h, 0.05, 0.90), secondary_fixed, 4.5, None);
    let on_secondary_fixed_variant =
        ensure_contrast(Color::from_hsl(sec_h, 0.05, 0.85), secondary_fixed_dim, 4.5, None);
    let on_tertiary_fixed =
        ensure_contrast(Color::from_hsl(ter_h, 0.05, 0.90), tertiary_fixed, 4.5, None);
    let on_tertiary_fixed_variant =
        ensure_contrast(Color::from_hsl(ter_h, 0.05, 0.85), tertiary_fixed_dim, 4.5, None);

    let surface_dim = adjust_surface(primary, MSF, 0.82);
    let surface_bright = adjust_surface(primary, MSF, 0.95);
    let outline = ensure_contrast(Color::from_hsl(primary_h, 0.05, 0.65), surface, 3.0, None);
    let outline_variant = ensure_contrast(Color::from_hsl(primary_h, 0.05, 0.75), surface, 3.0, None);
    let shadow = Color::from_hsl(primary_h, 0.05, 0.80);
    let scrim = Color::new(0, 0, 0);
    let inverse_surface = Color::from_hsl(primary_h, 0.05, 0.15);
    let inverse_on_surface = Color::from_hsl(primary_h, 0.03, 0.90);
    let inverse_primary = Color::from_hsl(primary_h, (primary_s * 0.5).min(MSP), 0.70);
    let background = surface;
    let on_background = on_surface;

    let hex = |c: Color| c.to_hex();
    vec![
        ("primary", hex(primary_adjusted)), ("on_primary", hex(on_primary)),
        ("primary_container", hex(primary_container)), ("on_primary_container", hex(on_primary_container)),
        ("primary_fixed", hex(primary_fixed)), ("primary_fixed_dim", hex(primary_fixed_dim)),
        ("on_primary_fixed", hex(on_primary_fixed)), ("on_primary_fixed_variant", hex(on_primary_fixed_variant)),
        ("surface_tint", hex(primary_adjusted)),
        ("secondary", hex(secondary_adjusted)), ("on_secondary", hex(on_secondary)),
        ("secondary_container", hex(secondary_container)), ("on_secondary_container", hex(on_secondary_container)),
        ("secondary_fixed", hex(secondary_fixed)), ("secondary_fixed_dim", hex(secondary_fixed_dim)),
        ("on_secondary_fixed", hex(on_secondary_fixed)), ("on_secondary_fixed_variant", hex(on_secondary_fixed_variant)),
        ("tertiary", hex(tertiary_adjusted)), ("on_tertiary", hex(on_tertiary)),
        ("tertiary_container", hex(tertiary_container)), ("on_tertiary_container", hex(on_tertiary_container)),
        ("tertiary_fixed", hex(tertiary_fixed)), ("tertiary_fixed_dim", hex(tertiary_fixed_dim)),
        ("on_tertiary_fixed", hex(on_tertiary_fixed)), ("on_tertiary_fixed_variant", hex(on_tertiary_fixed_variant)),
        ("error", hex(error)), ("on_error", hex(on_error)),
        ("error_container", hex(error_container)), ("on_error_container", hex(on_error_container)),
        ("surface", hex(surface)), ("on_surface", hex(on_surface)),
        ("surface_variant", hex(surface_variant)), ("on_surface_variant", hex(on_surface_variant)),
        ("surface_dim", hex(surface_dim)), ("surface_bright", hex(surface_bright)),
        ("surface_container_lowest", hex(lowest)), ("surface_container_low", hex(low)),
        ("surface_container", hex(container)),
        ("surface_container_high", hex(high)), ("surface_container_highest", hex(highest)),
        ("outline", hex(outline)), ("outline_variant", hex(outline_variant)),
        ("shadow", hex(shadow)), ("scrim", hex(scrim)),
        ("inverse_surface", hex(inverse_surface)), ("inverse_on_surface", hex(inverse_on_surface)),
        ("inverse_primary", hex(inverse_primary)),
        ("background", hex(background)), ("on_background", hex(on_background)),
    ]
    .into_iter()
    .map(|(k, v)| (k.to_string(), v))
    .collect()
}

pub fn generate_theme(palette: &[Color], mode: &str, scheme_type: &str) -> Scheme {
    match scheme_type {
        "vibrant" | "faithful" | "dysfunctional" => {
            if mode == "dark" {
                generate_normal_dark(palette)
            } else {
                generate_normal_light(palette)
            }
        }
        "muted" => {
            if mode == "dark" {
                generate_muted_dark(palette)
            } else {
                generate_muted_light(palette)
            }
        }
        _ => {
            if mode == "dark" {
                generate_material_dark(palette, scheme_type)
            } else {
                generate_material_light(palette, scheme_type)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pal() -> Vec<Color> {
        vec![
            Color::new(200, 60, 30),
            Color::new(30, 120, 200),
            Color::new(40, 180, 80),
            Color::new(240, 240, 240),
        ]
    }

    fn json(s: &Scheme) -> String {
        s.iter().map(|(k, v)| format!("\"{k}\": \"{v}\"")).collect::<Vec<_>>().join(", ")
    }

    #[test]
    fn all_modes_key_counts() {
        // Every generator emits surface_tint: 49 keys each.
        for (mode, kind) in [
            ("dark", "tonal-spot"), ("light", "tonal-spot"), ("dark", "content"),
            ("dark", "vibrant"), ("light", "faithful"), ("dark", "muted"), ("light", "muted"),
        ] {
            let s = generate_theme(&pal(), mode, kind);
            assert_eq!(s.len(), 49, "{mode}/{kind}");
        }
    }

    #[test]
    fn themes_match_python_oracle() {
        // Oracle: lib.theme.generate_theme on pal().
        let p = pal();
        assert_eq!(
            json(&generate_theme(&p, "dark", "vibrant")),
            "\"primary\": \"#e87b64\", \"on_primary\": \"#0d0a08\", \"primary_container\": \"#912008\", \"on_primary_container\": \"#f8d9d3\", \"primary_fixed\": \"#f5c6bc\", \"primary_fixed_dim\": \"#efa090\", \"on_primary_fixed\": \"#2c2321\", \"on_primary_fixed_variant\": \"#3b2e2b\", \"surface_tint\": \"#e87b64\", \"secondary\": \"#4e9de4\", \"on_secondary\": \"#080505\", \"secondary_container\": \"#074378\", \"on_secondary_container\": \"#d3e7f8\", \"secondary_fixed\": \"#bddaf5\", \"secondary_fixed_dim\": \"#90c2ee\", \"on_secondary_fixed\": \"#21272c\", \"on_secondary_fixed_variant\": \"#2b333b\", \"tertiary\": \"#58da7d\", \"on_tertiary\": \"#251b18\", \"tertiary_container\": \"#0e722a\", \"on_tertiary_container\": \"#d5f6df\", \"tertiary_fixed\": \"#bef4cd\", \"tertiary_fixed_dim\": \"#96e9ad\", \"on_tertiary_fixed\": \"#212c24\", \"on_tertiary_fixed_variant\": \"#2b3b30\", \"error\": \"#c83c1e\", \"on_error\": \"#251b18\", \"error_container\": \"#481004\", \"on_error_container\": \"#f8d9d3\", \"surface\": \"#291814\", \"on_surface\": \"#f3f2f2\", \"surface_variant\": \"#37201b\", \"on_surface_variant\": \"#b6b0af\", \"surface_dim\": \"#1c100d\", \"surface_bright\": \"#533028\", \"surface_container_lowest\": \"#150c0a\", \"surface_container_low\": \"#221411\", \"surface_container\": \"#452821\", \"surface_container_high\": \"#3e241e\", \"surface_container_highest\": \"#4c2c25\", \"outline\": \"#74645f\", \"outline_variant\": \"#756360\", \"shadow\": \"#291814\", \"scrim\": \"#000000\", \"inverse_surface\": \"#e8e4e3\", \"inverse_on_surface\": \"#282524\", \"inverse_primary\": \"#a23f2a\", \"background\": \"#291814\", \"on_background\": \"#f3f2f2\""
        );
        assert_eq!(
            json(&generate_theme(&p, "light", "faithful")),
            "\"primary\": \"#c83c1e\", \"on_primary\": \"#fafaf9\", \"primary_container\": \"#e8bbb1\", \"on_primary_container\": \"#43140a\", \"primary_fixed\": \"#b1351b\", \"primary_fixed_dim\": \"#852814\", \"on_primary_fixed\": \"#e9e3e2\", \"on_primary_fixed_variant\": \"#ded5d3\", \"surface_tint\": \"#c83c1e\", \"secondary\": \"#1b6ab1\", \"on_secondary\": \"#fafaf9\", \"secondary_container\": \"#9dc1e1\", \"on_secondary_container\": \"#0a2843\", \"secondary_fixed\": \"#1b6ab1\", \"secondary_fixed_dim\": \"#144f85\", \"on_secondary_fixed\": \"#e3e7e9\", \"on_secondary_fixed_variant\": \"#d3d9de\", \"tertiary\": \"#209241\", \"on_tertiary\": \"#fafaf9\", \"tertiary_container\": \"#90d4a4\", \"on_tertiary_container\": \"#0e3f1c\", \"tertiary_fixed\": \"#1fad48\", \"tertiary_fixed_dim\": \"#1b7e38\", \"on_tertiary_fixed\": \"#26322a\", \"on_tertiary_fixed_variant\": \"#edf1ee\", \"error\": \"#c83c1e\", \"on_error\": \"#fafaf9\", \"error_container\": \"#e8bbb1\", \"on_error_container\": \"#43140a\", \"surface\": \"#f8d9d3\", \"on_surface\": \"#1b1918\", \"surface_variant\": \"#f0ac9d\", \"on_surface_variant\": \"#524b4a\", \"surface_dim\": \"#f3bbaf\", \"surface_bright\": \"#fcece9\", \"surface_container_lowest\": \"#fcf0ed\", \"surface_container_low\": \"#fae1dc\", \"surface_container\": \"#f6cac1\", \"surface_container_high\": \"#f4c3b8\", \"surface_container_highest\": \"#f0b5a8\", \"outline\": \"#ab7164\", \"outline_variant\": \"#a1756c\", \"shadow\": \"#d7c5c1\", \"scrim\": \"#000000\", \"inverse_surface\": \"#292423\", \"inverse_on_surface\": \"#e7e5e4\", \"inverse_primary\": \"#e09585\", \"background\": \"#f8d9d3\", \"on_background\": \"#1b1918\""
        );
        assert_eq!(
            json(&generate_theme(&p, "dark", "muted")),
            "\"primary\": \"#b39d98\", \"on_primary\": \"#1a1616\", \"primary_container\": \"#584541\", \"on_primary_container\": \"#e7e5e4\", \"primary_fixed\": \"#ded5d3\", \"primary_fixed_dim\": \"#c9b9b6\", \"on_primary_fixed\": \"#282524\", \"on_primary_fixed_variant\": \"#363130\", \"surface_tint\": \"#b39d98\", \"secondary\": \"#a5978d\", \"on_secondary\": \"#0b0909\", \"secondary_container\": \"#493e36\", \"on_secondary_container\": \"#e7e5e4\", \"secondary_fixed\": \"#ddd8d4\", \"secondary_fixed_dim\": \"#c7beb8\", \"on_secondary_fixed\": \"#282624\", \"on_secondary_fixed_variant\": \"#363330\", \"tertiary\": \"#a39d8f\", \"on_tertiary\": \"#131010\", \"tertiary_container\": \"#494436\", \"on_tertiary_container\": \"#e7e6e4\", \"tertiary_fixed\": \"#dcdad5\", \"tertiary_fixed_dim\": \"#c5c2b9\", \"on_tertiary_fixed\": \"#282724\", \"on_tertiary_fixed_variant\": \"#363430\", \"error\": \"#c83c1e\", \"on_error\": \"#221d1c\", \"error_container\": \"#2c2321\", \"on_error_container\": \"#e7e5e4\", \"surface\": \"#211d1c\", \"on_surface\": \"#f3f2f2\", \"surface_variant\": \"#2c2726\", \"on_surface_variant\": \"#b5b1b0\", \"surface_dim\": \"#161313\", \"surface_bright\": \"#423a38\", \"surface_container_lowest\": \"#110f0e\", \"surface_container_low\": \"#1c1817\", \"surface_container\": \"#37302f\", \"surface_container_high\": \"#322c2a\", \"surface_container_highest\": \"#3d3534\", \"outline\": \"#6f6765\", \"outline_variant\": \"#6f6764\", \"shadow\": \"#211d1c\", \"scrim\": \"#000000\", \"inverse_surface\": \"#e7e5e4\", \"inverse_on_surface\": \"#272625\", \"inverse_primary\": \"#755c57\", \"background\": \"#211d1c\", \"on_background\": \"#f3f2f2\""
        );
        assert_eq!(
            json(&generate_theme(&p, "light", "muted")),
            "\"primary\": \"#846862\", \"on_primary\": \"#fafafa\", \"primary_container\": \"#d1c9c7\", \"on_primary_container\": \"#282524\", \"primary_fixed\": \"#755c57\", \"primary_fixed_dim\": \"#584541\", \"on_primary_fixed\": \"#e7e5e4\", \"on_primary_fixed_variant\": \"#dbd8d7\", \"surface_tint\": \"#846862\", \"secondary\": \"#72645a\", \"on_secondary\": \"#fafafa\", \"secondary_container\": \"#c4bfbb\", \"on_secondary_container\": \"#282624\", \"secondary_fixed\": \"#72645a\", \"secondary_fixed_dim\": \"#564b44\", \"on_secondary_fixed\": \"#e7e5e4\", \"on_secondary_fixed_variant\": \"#dbd8d7\", \"tertiary\": \"#625c50\", \"on_tertiary\": \"#fafafa\", \"tertiary_container\": \"#b6b4ae\", \"on_tertiary_container\": \"#282724\", \"tertiary_fixed\": \"#70695c\", \"tertiary_fixed_dim\": \"#544f45\", \"on_tertiary_fixed\": \"#eaeae8\", \"on_tertiary_fixed_variant\": \"#dbd9d7\", \"error\": \"#c83c1e\", \"on_error\": \"#fafafa\", \"error_container\": \"#efb6a9\", \"on_error_container\": \"#282524\", \"surface\": \"#e8e4e3\", \"on_surface\": \"#1a1919\", \"surface_variant\": \"#cbc4c2\", \"on_surface_variant\": \"#555251\", \"surface_dim\": \"#d5cfcd\", \"surface_bright\": \"#f3f2f1\", \"surface_container_lowest\": \"#f6f4f4\", \"surface_container_low\": \"#eceae9\", \"surface_container\": \"#ded9d8\", \"surface_container_high\": \"#d9d4d3\", \"surface_container_highest\": \"#d0c9c8\", \"outline\": \"#8b817f\", \"outline_variant\": \"#8b817f\", \"shadow\": \"#cfcac9\", \"scrim\": \"#000000\", \"inverse_surface\": \"#282524\", \"inverse_on_surface\": \"#e6e5e5\", \"inverse_primary\": \"#beaba7\", \"background\": \"#e8e4e3\", \"on_background\": \"#1a1919\""
        );
    }

    #[test]
    fn empty_palette_fallbacks() {
        assert_eq!(generate_theme(&[], "dark", "vibrant")[0].1, generate_normal_dark(&[])[0].1);
        assert_eq!(generate_theme(&[], "light", "tonal-spot")[0].1, generate_material_light(&[], "tonal-spot")[0].1);
    }
}
