#![forbid(unsafe_code)]

//! Find installed Noctalia theme extensions for VSCode/VSCodium.
//! Mirrors Scripts/python/src/theming/vscode-helper.py.

use std::env;
use std::path::{Path, PathBuf};

const DEFAULT_PREFIX: &str = "nosd.nosdtheme-";
const THEME_SUFFIX: [&str; 2] = ["themes", "NosdTheme-color-theme.json"];

/// Expand a leading `~` against $HOME (mirrors Path.expanduser).
fn expanduser(p: &str) -> PathBuf {
    if let Some(rest) = p.strip_prefix('~') {
        if rest.is_empty() || rest.starts_with('/') {
            if let Ok(home) = env::var("HOME") {
                return PathBuf::from(home + rest);
            }
        }
    }
    PathBuf::from(p)
}

/// Collect theme file paths for extension dirs matching `prefix`.
pub fn find_themes(extensions_dir: &Path, prefix: &str) -> Vec<PathBuf> {
    let entries = match std::fs::read_dir(extensions_dir) {
        Ok(it) => it,
        Err(_) => return Vec::new(),
    };
    let mut out: Vec<PathBuf> = entries
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| {
            p.is_dir()
                && p.file_name()
                    .and_then(|n| n.to_str())
                    .is_some_and(|n| n.starts_with(prefix))
        })
        .map(|d| d.join(THEME_SUFFIX[0]).join(THEME_SUFFIX[1]))
        .collect();
    out.sort();
    out
}

pub fn run(args: &[String]) -> i32 {
    let dir_arg = args.first().map(String::as_str).unwrap_or("");
    if dir_arg.is_empty() {
        eprintln!("Usage: nosd-helpers vscode-themes <extensions_dir> [prefix]");
        return 2;
    }
    let prefix = args.get(1).map(String::as_str).unwrap_or(DEFAULT_PREFIX);
    let dir = expanduser(dir_arg);
    let results = find_themes(&dir, prefix);
    if results.is_empty() {
        eprintln!("No matching extension found in {dir_arg}");
        return 1;
    }
    for p in &results {
        println!("{}", p.display());
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmpdir(tag: &str) -> PathBuf {
        let d = env::temp_dir().join(format!("nosd-vscode-test-{tag}"));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn finds_matching_prefix_only() {
        let d = tmpdir("match");
        std::fs::create_dir_all(d.join("nosd.nosdtheme-1.0.0")).unwrap();
        std::fs::create_dir_all(d.join("other.theme-2.0.0")).unwrap();
        let got = find_themes(&d, DEFAULT_PREFIX);
        assert_eq!(got.len(), 1);
        assert!(got[0].ends_with("themes/NosdTheme-color-theme.json"));
        let _ = std::fs::remove_dir_all(&d);
    }

    #[test]
    fn missing_dir_yields_empty() {
        let got = find_themes(Path::new("/nonexistent-nosd-dir"), DEFAULT_PREFIX);
        assert!(got.is_empty());
    }

    #[test]
    fn custom_prefix() {
        let d = tmpdir("prefix");
        std::fs::create_dir_all(d.join("custom.foo")).unwrap();
        assert_eq!(find_themes(&d, "custom.").len(), 1);
        assert!(find_themes(&d, "other.").is_empty());
        let _ = std::fs::remove_dir_all(&d);
    }
}
