#![forbid(unsafe_code)]

//! nosd-theme: wallpaper color extraction, Material theme generation and
//! Matugen-compatible template rendering.
//!
//! Rust port of Scripts/python/src/theming/template-processor.py (+ lib/).
//! CLI mirrors the python tool argument for argument so QML callers only swap
//! the binary name. All names use the nosd scheme (nosd.css, NosdTheme, ...).

use std::path::{Path, PathBuf};

use nosd_theme::color::Color;
use nosd_theme::image::{read_image, ImageError};
use nosd_theme::{palette, quantizer, scheme, theme};
use nosd_theme::renderer::{TemplateRenderer, ThemeData};

const M3_SCHEMES: &[&str] = &["tonal-spot", "content", "fruit-salad", "rainbow", "monochrome"];

const VALID_SCHEME_TYPES: &[&str] = &[
    "tonal-spot", "content", "fruit-salad", "rainbow", "monochrome", "vibrant", "faithful",
    "dysfunctional", "muted",
];

struct Args {
    image: Option<String>,
    scheme_type: String,
    modes: Vec<String>,
    output: Option<PathBuf>,
    renders: Vec<String>,
    config: Option<PathBuf>,
    scheme: Option<PathBuf>,
    default_mode: String,
}

fn usage_error(msg: &str) -> ! {
    eprintln!("Error: {msg}");
    eprintln!("Usage: nosd-theme IMAGE_OR_JSON [--scheme-type T] [--dark|--light|--both] [-o OUT] [-r in:out] [-c CONFIG] [--mode M] [--scheme JSON] [--default-mode M]");
    std::process::exit(2);
}

fn parse_args() -> Args {
    let mut a = Args {
        image: None,
        scheme_type: "tonal-spot".to_string(),
        modes: Vec::new(),
        output: None,
        renders: Vec::new(),
        config: None,
        scheme: None,
        default_mode: "dark".to_string(),
    };
    let mut mode_flag: Option<String> = None;
    let mut dark = false;
    let mut light = false;
    let mut raw: Vec<String> = std::env::args().skip(1).collect();
    // Expand --opt=val.
    let mut argv = Vec::new();
    for r in raw.drain(..) {
        if r.starts_with("--") && r.contains('=') {
            let (k, v) = r.split_once('=').unwrap();
            argv.push(k.to_string());
            argv.push(v.to_string());
        } else {
            argv.push(r);
        }
    }
    let mut i = 0;
    while i < argv.len() {
        let s = argv[i].as_str();
        let next = |i: &mut usize| -> String {
            *i += 1;
            if *i >= argv.len() {
                usage_error("option requires a value");
            }
            argv[*i].clone()
        };
        match s {
            "--scheme-type" => {
                let v = next(&mut i);
                if !VALID_SCHEME_TYPES.contains(&v.as_str()) {
                    usage_error(&format!("invalid scheme type '{v}'"));
                }
                a.scheme_type = v;
            }
            "--dark" => dark = true,
            "--light" => light = true,
            "--both" => {}
            "-o" | "--output" => a.output = Some(PathBuf::from(next(&mut i))),
            "-r" | "--render" => a.renders.push(next(&mut i)),
            "-c" | "--config" => a.config = Some(PathBuf::from(next(&mut i))),
            "--mode" => {
                let v = next(&mut i);
                if v != "dark" && v != "light" {
                    usage_error(&format!("invalid mode '{v}'"));
                }
                mode_flag = Some(v);
            }
            "--scheme" => a.scheme = Some(PathBuf::from(next(&mut i))),
            "--default-mode" => {
                let v = next(&mut i);
                if v != "dark" && v != "light" {
                    usage_error(&format!("invalid default mode '{v}'"));
                }
                a.default_mode = v;
            }
            s if s.starts_with('-') => usage_error(&format!("unknown option '{s}'")),
            pos => {
                if a.image.is_some() {
                    usage_error("too many positional arguments");
                }
                a.image = Some(pos.to_string());
            }
        }
        i += 1;
    }
    a.modes = match mode_flag {
        Some(m) => vec![m],
        None if dark => vec!["dark".to_string()],
        None if light => vec!["light".to_string()],
        None => vec!["dark".to_string(), "light".to_string()],
    };
    a
}

/// Python str() for a JSON value (best-effort palette flatten fallback).
fn json_py_repr(v: &serde_json::Value) -> String {
    match v {
        serde_json::Value::Null => "None".to_string(),
        serde_json::Value::Bool(true) => "True".to_string(),
        serde_json::Value::Bool(false) => "False".to_string(),
        serde_json::Value::Number(n) => n.to_string(),
        serde_json::Value::String(s) => format!("'{s}'"),
        serde_json::Value::Array(items) => {
            format!("[{}]", items.iter().map(json_py_repr).collect::<Vec<_>>().join(", "))
        }
        serde_json::Value::Object(map) => {
            format!(
                "{{{}}}",
                map.iter().map(|(k, vv)| format!("'{k}': {}", json_py_repr(vv))).collect::<Vec<_>>().join(", ")
            )
        }
    }
}

fn theme_to_json(theme: &ThemeData) -> serde_json::Value {
    let mut top = serde_json::Map::new();
    for (mode, data) in theme {
        let mut m = serde_json::Map::new();
        for (k, v) in data {
            m.insert(k.clone(), serde_json::Value::String(v.clone()));
        }
        top.insert(mode.clone(), serde_json::Value::Object(m));
    }
    serde_json::Value::Object(top)
}

fn run() -> i32 {
    let args = parse_args();
    let mut result: ThemeData = Vec::new();

    if let Some(scheme_path) = &args.scheme {
        if !scheme_path.exists() {
            eprintln!("Error: Scheme file not found: {}", scheme_path.display());
            return 1;
        }
        let text = match std::fs::read_to_string(scheme_path) {
            Ok(t) => t,
            Err(e) => {
                eprintln!("Error processing scheme: {e}");
                return 1;
            }
        };
        let data: serde_json::Value = match serde_json::from_str(&text) {
            Ok(v) => v,
            Err(e) => {
                eprintln!("Error parsing scheme JSON: {e}");
                return 1;
            }
        };
        for mode in &args.modes {
            let mode_data = if let Some(m) = data.get(mode) {
                m
            } else if data.get("mPrimary").is_some() {
                &data
            } else {
                eprintln!("Error: Invalid scheme format - missing '{mode}' or 'mPrimary'");
                return 1;
            };
            let Some(obj) = mode_data.as_object() else {
                eprintln!("Error: Missing required color in scheme: '{mode}' is not an object");
                return 1;
            };
            match scheme::expand_predefined_scheme(obj, mode) {
                Some(mut expanded) => {
                    scheme::inject_terminal_colors(&mut expanded, obj);
                    result.push((mode.clone(), expanded));
                }
                None => {
                    eprintln!("Error: Missing required color in scheme");
                    return 1;
                }
            }
        }
    } else {
        let Some(image_str) = &args.image else {
            eprintln!("Error: Image path is required (unless --scheme is used)");
            return 1;
        };
        let image_path = Path::new(image_str);
        if !image_path.exists() {
            eprintln!("Error: Image not found: {}", image_path.display());
            return 1;
        }
        if image_path.extension().and_then(|e| e.to_str()).map(|e| e.eq_ignore_ascii_case("json")).unwrap_or(false) {
            let text = match std::fs::read_to_string(image_path) {
                Ok(t) => t,
                Err(e) => {
                    eprintln!("Error reading JSON palette: {e}");
                    return 1;
                }
            };
            let data: serde_json::Value = match serde_json::from_str(&text) {
                Ok(v) => v,
                Err(e) => {
                    eprintln!("Error reading JSON palette: {e}");
                    return 1;
                }
            };
            let colors_data = data.get("colors").unwrap_or(&data);
            let Some(obj) = colors_data.as_object() else {
                eprintln!("Error reading JSON palette: palette is not an object");
                return 1;
            };
            let mut flat: Vec<(String, String)> = Vec::new();
            for (k, v) in obj {
                if let Some(hex) = v
                    .get("default")
                    .and_then(|d| d.get("hex"))
                    .and_then(|h| h.as_str())
                {
                    flat.push((k.clone(), hex.to_string()));
                } else if let Some(s) = v.as_str() {
                    flat.push((k.clone(), s.to_string()));
                } else {
                    flat.push((k.clone(), json_py_repr(v)));
                }
            }
            for mode in &args.modes {
                result.push((mode.clone(), flat.clone()));
            }
        } else {
            if !image_path.is_file() {
                eprintln!("Error: Not a file: {}", image_path.display());
                return 1;
            }
            let filter = if M3_SCHEMES.contains(&args.scheme_type.as_str()) { "Triangle" } else { "Box" };
            let pixels = match read_image(image_path, filter) {
                Ok(p) => p,
                Err(ImageError::Io(e)) => {
                    eprintln!("Unexpected error reading image: {e}");
                    return 1;
                }
                Err(e) => {
                    eprintln!("Error reading image: {e}");
                    return 1;
                }
            };
            let palette: Vec<Color> = match args.scheme_type.as_str() {
                "vibrant" => palette::extract_palette(&pixels, 5, "chroma"),
                "faithful" => palette::extract_palette(&pixels, 5, "count"),
                "dysfunctional" => palette::extract_palette(&pixels, 5, "dysfunctional"),
                "muted" => palette::extract_palette(&pixels, 5, "muted"),
                _ => {
                    let argb = quantizer::extract_source_color(&pixels, quantizer::FALLBACK_ARGB);
                    let (r, g, b) = quantizer::rgb_from_argb(argb);
                    vec![Color::new(r, g, b)]
                }
            };
            if palette.is_empty() {
                eprintln!("Error: Could not extract colors from image");
                return 1;
            }
            for mode in &args.modes {
                result.push((mode.clone(), theme::generate_theme(&palette, mode, &args.scheme_type)));
            }
        }
    }

    let json_output = serde_json::to_string_pretty(&theme_to_json(&result)).unwrap_or_default();
    if let Some(out) = &args.output {
        match std::fs::write(out, &json_output) {
            Ok(()) => eprintln!("Theme written to: {}", out.display()),
            Err(e) => {
                eprintln!("Error writing output: {e}");
                return 1;
            }
        }
    } else if args.renders.is_empty() && args.config.is_none() {
        println!("{json_output}");
    }

    if !args.renders.is_empty() || args.config.is_some() {
        let mut renderer = TemplateRenderer::with_options(
            result,
            true,
            &args.default_mode,
            args.image.clone(),
            &args.scheme_type,
        );
        for spec in &args.renders {
            if !spec.contains(':') {
                eprintln!("Error: Invalid render spec (must be input:output): {spec}");
                continue;
            }
            let (inp, outp) = spec.split_once(':').unwrap();
            let input_path = expand_user(Path::new(inp));
            let output_path = expand_user(Path::new(outp));
            if !input_path.exists() {
                eprintln!("Error: Template not found: {}", input_path.display());
                continue;
            }
            renderer.render_file(&input_path, &output_path);
        }
        if let Some(cfg) = &args.config {
            if !cfg.exists() {
                eprintln!("Error: Config file not found: {}", cfg.display());
            } else {
                renderer.process_config_file(cfg);
            }
        }
    }
    0
}

fn expand_user(p: &Path) -> PathBuf {
    let s = p.to_string_lossy();
    if let Some(rest) = s.strip_prefix("~/").or_else(|| (s == "~").then_some("")) {
        if let Ok(home) = std::env::var("HOME") {
            return PathBuf::from(home).join(rest);
        }
    }
    p.to_path_buf()
}

fn main() {
    std::process::exit(run());
}
