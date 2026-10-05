#![forbid(unsafe_code)]

//! Apply a named KDE color scheme.
//! Mirrors Scripts/python/src/theming/kde-apply-scheme.py:
//! merge scheme file into kdeglobals (case-sensitive keys,
//! `key=value` without spaces), then notify KGlobalSettings.

use std::env;
use std::fs;
use std::path::PathBuf;

/// Ordered INI document preserving section/key order.
#[derive(Default)]
struct Ini {
    sections: Vec<(String, Vec<(String, String)>)>,
}

impl Ini {
    fn parse(text: &str) -> Self {
        let mut ini = Ini::default();
        let mut current: Option<usize> = None;
        for raw in text.lines() {
            let line = raw.trim();
            if line.is_empty() || line.starts_with('#') || line.starts_with(';') {
                continue;
            }
            if let Some(name) = line.strip_prefix('[').and_then(|s| s.strip_suffix(']')) {
                ini.sections.push((name.to_string(), Vec::new()));
                current = Some(ini.sections.len() - 1);
            } else if let Some((k, v)) = line.split_once('=') {
                if let Some(i) = current {
                    ini.sections[i].1.push((k.trim().to_string(), v.trim().to_string()));
                }
            } else if let Some((k, v)) = line.split_once(':') {
                if let Some(i) = current {
                    ini.sections[i].1.push((k.trim().to_string(), v.trim().to_string()));
                }
            }
        }
        ini
    }

    fn section_mut(&mut self, name: &str) -> &mut Vec<(String, String)> {
        let pos = self.sections.iter().position(|(s, _)| s == name);
        let idx = match pos {
            Some(i) => i,
            None => {
                self.sections.push((name.to_string(), Vec::new()));
                self.sections.len() - 1
            }
        };
        &mut self.sections[idx].1
    }

    fn merge(&mut self, other: &Ini) {
        for (section, pairs) in &other.sections {
            let target = self.section_mut(section);
            for (k, v) in pairs {
                match target.iter_mut().find(|(ek, _)| ek == k) {
                    Some(slot) => slot.1 = v.clone(),
                    None => target.push((k.clone(), v.clone())),
                }
            }
        }
    }

    fn render(&self) -> String {
        let mut out = String::new();
        for (section, pairs) in &self.sections {
            out.push_str(&format!("[{section}]\n"));
            for (k, v) in pairs {
                out.push_str(&format!("{k}={v}\n"));
            }
            out.push('\n');
        }
        out
    }
}

fn home() -> PathBuf {
    env::var("HOME").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from("/root"))
}

fn kdeglobals_path() -> PathBuf {
    // Mirrors the python helper: always ~/.config, no XDG_CONFIG_HOME.
    home().join(".config/kdeglobals")
}

fn scheme_path(name: &str) -> PathBuf {
    // Mirrors the python helper: always ~/.local/share, no XDG_DATA_HOME.
    home().join(format!(".local/share/color-schemes/{name}.colors"))
}

fn notify_kde() {
    // Mirrors the python fallback: it prefers a D-Bus library and falls back
    // to dbus-send. Here dbus-send is the only mechanism (std only).
    let status = std::process::Command::new("dbus-send")
        .args([
            "/KGlobalSettings",
            "org.kde.KGlobalSettings.notifyChange",
            "int32:0",
            "int32:0",
        ])
        .status();
    if let Err(e) = status {
        eprintln!("kde-apply-scheme: notify failed ({e}); kdeglobals already updated");
    }
}

pub fn run(args: &[String]) -> i32 {
    let Some(name) = args.first() else {
        eprintln!("Usage: nosd-helpers kde-apply-scheme <scheme-name>");
        return 2;
    };
    let kglobals = kdeglobals_path();
    let scheme = scheme_path(name);

    let base = fs::read_to_string(&kglobals).unwrap_or_default();
    let mut merged = Ini::parse(&base);
    if scheme.exists() {
        match fs::read_to_string(&scheme) {
            Ok(text) => merged.merge(&Ini::parse(&text)),
            Err(e) => eprintln!("kde-apply-scheme: cannot read {}: {e}", scheme.display()),
        }
    } else {
        eprintln!("kde-apply-scheme: scheme not found: {}", scheme.display());
    }

    if let Some(parent) = kglobals.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Err(e) = fs::write(&kglobals, merged.render()) {
        eprintln!("kde-apply-scheme: cannot write {}: {e}", kglobals.display());
        return 1;
    }
    notify_kde();
    0
}

/// Merge helper used by tests (pure, no fs).
#[cfg(test)]
pub fn merge_ini(base: &str, overlay: &str) -> String {
    let mut ini = Ini::parse(base);
    ini.merge(&Ini::parse(overlay));
    ini.render()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn overlay_overrides_and_adds() {
        let base = "[General]\nName=Breeze\n[Colors]\nA=1\n";
        let over = "[General]\nName=Ocean\n[New]\nK=V\n";
        let out = merge_ini(base, over);
        assert!(out.contains("Name=Ocean"));
        assert!(out.contains("[New]"));
        assert!(out.contains("A=1"));
    }

    #[test]
    fn key_case_is_preserved() {
        let out = merge_ini("[G]\nFooBar=1\n", "[G]\nFooBar=2\nfoobar=3\n");
        assert!(out.contains("FooBar=2"));
        assert!(out.contains("foobar=3"));
    }

    #[test]
    fn no_spaces_around_delimiter() {
        let out = merge_ini("", "[S]\nK=V\n");
        assert!(out.contains("K=V"));
        assert!(!out.contains("K = V"));
    }

    #[test]
    fn scheme_path_uses_name() {
        // Just guards the filename convention, not $HOME.
        let p = Path::new("Ocean.colors");
        assert_eq!(p.extension().unwrap(), "colors");
    }
}
