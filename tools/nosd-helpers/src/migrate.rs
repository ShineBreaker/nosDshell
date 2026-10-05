#![forbid(unsafe_code)]

//! Migrate old-format color schemes by redownloading them.
//! Mirrors Scripts/python/src/theming/migrate-colorschemes.py.

use std::fs;
use std::path::{Path, PathBuf};

const REGISTRY_URL: &str =
    "https://raw.githubusercontent.com/noctalia-dev/noctalia-colorschemes/main/registry.json";
const RAW_BASE_URL: &str = "https://raw.githubusercontent.com/noctalia-dev/noctalia-colorschemes/main/";

/// True when the scheme already uses the new terminal format.
pub fn is_valid_format(data: &serde_json::Value) -> bool {
    for variant in ["dark", "light"] {
        if data
            .get(variant)
            .and_then(|v| v.get("terminal"))
            .and_then(|t| t.get("normal"))
            .and_then(|n| n.get("black"))
            .is_some()
        {
            return true;
        }
    }
    false
}

/// Percent-encode a URL path segment (mirrors urllib.parse.quote).
pub fn quote_segment(s: &str) -> String {
    let mut out = String::new();
    for b in s.as_bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') {
            out.push(*b as char);
        } else {
            out.push_str(&format!("%{b:02X}"));
        }
    }
    out
}

fn fetch_json(url: &str) -> Result<serde_json::Value, String> {
    let body = ureq::get(url)
        .call()
        .map_err(|e| e.to_string())?
        .body_mut()
        .read_to_string()
        .map_err(|e| e.to_string())?;
    serde_json::from_str(&body).map_err(|e| e.to_string())
}

pub fn migrate(config_dir: &Path) {
    let schemes_dir = config_dir.join("colorschemes");
    if !schemes_dir.exists() {
        return;
    }
    let registry = match fetch_json(REGISTRY_URL) {
        Ok(v) => v,
        Err(e) => {
            println!("Error fetching registry: {e}");
            return;
        }
    };
    let mut theme_map = std::collections::HashMap::new();
    if let Some(themes) = registry.get("themes").and_then(|t| t.as_array()) {
        for t in themes {
            if let (Some(name), Some(path)) = (
                t.get("name").and_then(|n| n.as_str()),
                t.get("path").and_then(|p| p.as_str()),
            ) {
                theme_map.insert(name.to_string(), path.to_string());
            }
        }
    }
    let entries: Vec<PathBuf> = fs::read_dir(&schemes_dir)
        .map(|it| it.filter_map(|e| e.ok()).map(|e| e.path()).collect())
        .unwrap_or_default();
    for scheme_dir in entries {
        if !scheme_dir.is_dir() {
            continue;
        }
        let Some(scheme_name) = scheme_dir.file_name().and_then(|n| n.to_str()) else {
            continue;
        };
        let json_file = scheme_dir.join(format!("{scheme_name}.json"));
        if !json_file.exists() {
            continue;
        }
        let data: serde_json::Value = match fs::read_to_string(&json_file)
            .ok()
            .and_then(|t| serde_json::from_str(&t).ok())
        {
            Some(v) => v,
            None => continue,
        };
        if is_valid_format(&data) {
            continue;
        }
        println!("Scheme '{scheme_name}' has old format. Attempting to redownload...");
        let remote_path = theme_map
            .get(scheme_name)
            .cloned()
            .unwrap_or_else(|| scheme_name.to_string());
        let remote_url = format!(
            "{RAW_BASE_URL}{}/{}.json",
            quote_segment(&remote_path),
            quote_segment(scheme_name)
        );
        match fetch_json(&remote_url) {
            Ok(new_data) => {
                let text = serde_json::to_string_pretty(&new_data).unwrap_or_default();
                if fs::write(&json_file, text).is_ok() {
                    println!("Successfully migrated '{scheme_name}'");
                } else {
                    println!("Failed to migrate '{scheme_name}': cannot write file");
                }
            }
            Err(e) => println!("Failed to migrate '{scheme_name}': {e}"),
        }
    }
}

pub fn run(args: &[String]) -> i32 {
    let Some(dir) = args.first() else {
        println!("Usage: migrate-colorschemes.py <config_dir>");
        return 1;
    };
    migrate(Path::new(dir));
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_new_format() {
        let v: serde_json::Value = serde_json::from_str(
            r##"{"dark": {"terminal": {"normal": {"black": "#000"}}}}"##,
        )
        .unwrap();
        assert!(is_valid_format(&v));
    }

    #[test]
    fn rejects_old_format() {
        for doc in [
            r##"{"dark": {"terminal": {"black": "#000"}}}"##,
            r#"{"dark": {}}"#,
            r#"{}"#,
            r#"{"light": {"terminal": {"normal": {}}}}"#,
        ] {
            let v: serde_json::Value = serde_json::from_str(doc).unwrap();
            assert!(!is_valid_format(&v), "{doc}");
        }
    }

    #[test]
    fn quote_matches_python_for_names() {
        // urllib.parse.quote("My Theme") == "My%20Theme"
        assert_eq!(quote_segment("My Theme"), "My%20Theme");
        assert_eq!(quote_segment("catppuccin"), "catppuccin");
        // '/' is escaped here (segments never contain it; quote(safe='/')
        // would keep it, but our inputs are single path segments).
        assert_eq!(quote_segment("a/b"), "a%2Fb");
    }

    #[test]
    fn missing_dir_is_silent_success() {
        migrate(Path::new("/nonexistent-nosd-config-dir"));
    }
}
