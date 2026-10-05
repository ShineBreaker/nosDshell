#![forbid(unsafe_code)]

//! GTK refresh helper.
//! Mirrors Scripts/python/src/theming/gtk-refresh.py:
//! ensure gtk.css imports nosdshell.css (GTK3/4), then push the
//! light/dark preference via gsettings (dconf fallback).

use std::env;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;

const GTK_IMPORT: &str = "@import url(\"nosdshell.css\");";

fn config_dir() -> PathBuf {
    if let Ok(xdg) = env::var("XDG_CONFIG_HOME") {
        if !xdg.is_empty() {
            return expand_tilde(&xdg);
        }
    }
    home().join(".config")
}

fn home() -> PathBuf {
    env::var("HOME").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from("/root"))
}

fn expand_tilde(p: &str) -> PathBuf {
    if let Some(rest) = p.strip_prefix('~') {
        if rest.is_empty() || rest.starts_with('/') {
            return home().join(rest.trim_start_matches('/'));
        }
    }
    PathBuf::from(p)
}

fn theme_exists(name: &str) -> bool {
    let mut bases: Vec<PathBuf> = vec![
        home().join(".themes"),
        home().join(".local/share/themes"),
        PathBuf::from("/usr/share/themes"),
        PathBuf::from("/usr/local/share/themes"),
    ];
    if let Ok(dirs) = env::var("XDG_DATA_DIRS") {
        for d in dirs.split(':').filter(|s| !s.is_empty()) {
            bases.push(PathBuf::from(d).join("themes"));
        }
    }
    bases.iter().any(|b| b.join(name).is_dir())
}

fn on_path(bin: &str) -> bool {
    env::var_os("PATH").is_some_and(|paths| {
        env::split_paths(&paths).any(|d| d.join(bin).is_file())
    })
}

fn run_cmd(bin: &str, args: &[&str]) -> Option<String> {
    let out = Command::new(bin).args(args).output().ok()?;
    if out.status.success() {
        Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
    } else {
        let err = String::from_utf8_lossy(&out.stderr).trim().to_string();
        if !err.is_empty() {
            eprintln!("Error running {bin} {}: {err}", args.join(" "));
        }
        None
    }
}

/// Append the nosdshell.css import to gtk.css unless already present.
/// Returns false when the colors file is missing.
pub fn ensure_gtk_css_import(gtk_css: &Path, colors_file: &Path, label: &str) -> bool {
    if !colors_file.exists() {
        eprintln!("Error: {label} nosdshell.css not found at {}", colors_file.display());
        return false;
    }
    if gtk_css.exists() || gtk_css.is_symlink() {
        let content = fs::read_to_string(gtk_css).unwrap_or_default();
        if content.contains("nosdshell.css") && content.contains("@import") {
            return true;
        }
        // Symlink-aware write, mirroring the python helper.
        let mut target: PathBuf = gtk_css.to_path_buf();
        if gtk_css.is_symlink() {
            if let Ok(resolved) = fs::canonicalize(gtk_css) {
                let writable = resolved
                    .metadata()
                    .map(|m| m.permissions().mode() & 0o222 != 0)
                    .unwrap_or(false);
                if writable {
                    target = resolved;
                } else {
                    let original = fs::read_to_string(&resolved).unwrap_or_default();
                    let _ = fs::remove_file(gtk_css);
                    let _ = fs::write(gtk_css, original);
                    target = gtk_css.to_path_buf();
                }
            }
            // Re-read through the (possibly replaced) path.
            let content = fs::read_to_string(gtk_css).unwrap_or_default();
            append_import(gtk_css, &target, &content, label);
        } else {
            append_import(gtk_css, &target, &content, label);
        }
    } else {
        if let Some(parent) = gtk_css.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let _ = fs::write(gtk_css, format!("{GTK_IMPORT}\n"));
        println!("Created {label} gtk.css with nosdshell.css import");
    }
    true
}

fn append_import(gtk_css: &Path, target: &Path, content: &str, label: &str) {
    let mut new_content = content.trim_end().to_string();
    if !new_content.is_empty() && !new_content.ends_with('\n') {
        new_content.push('\n');
    }
    new_content.push_str(&format!("\n{GTK_IMPORT}\n"));
    let dest = if target != gtk_css { target } else { gtk_css };
    let _ = fs::write(dest, new_content);
    println!("Appended {label} nosdshell.css import to gtk.css");
}

fn sync_system_appearance(mode: &str, update_gtk_theme: bool) {
    let has_gsettings = on_path("gsettings");
    let has_dconf = on_path("dconf");
    if !has_gsettings && !has_dconf {
        println!("No gsettings or dconf found, skip system appearance sync");
        return;
    }
    let target_theme = if mode == "light" { "adw-gtk3" } else { "adw-gtk3-dark" };
    let theme_available = update_gtk_theme && theme_exists(target_theme);
    if update_gtk_theme && !theme_available {
        println!("Theme '{target_theme}' not found, skipping GTK theme set");
    }
    if has_gsettings {
        if let Some(schemas) = run_cmd("gsettings", &["list-schemas"]) {
            if schemas.contains("org.gnome.desktop.interface") {
                run_cmd(
                    "gsettings",
                    &["set", "org.gnome.desktop.interface", "color-scheme", &format!("prefer-{mode}")],
                );
                if theme_available {
                    run_cmd(
                        "gsettings",
                        &["set", "org.gnome.desktop.interface", "gtk-theme", target_theme],
                    );
                }
                return;
            }
        }
    }
    if has_dconf {
        run_cmd(
            "dconf",
            &["write", "/org/gnome/desktop/interface/color-scheme", &format!("'prefer-{mode}'")],
        );
        if theme_available {
            run_cmd(
                "dconf",
                &["write", "/org/gnome/desktop/interface/gtk-theme", &format!("'{target_theme}'")],
            );
        }
    }
}

pub fn run(args: &[String]) -> i32 {
    let mut rest = args;
    let mut appearance_only = false;
    if rest.first().map(String::as_str) == Some("--appearance-only") {
        appearance_only = true;
        rest = &rest[1..];
    }
    let Some(mode) = rest.first() else {
        eprintln!("Usage: nosd-helpers gtk-refresh [--appearance-only] (dark|light)");
        return 1;
    };
    if (mode != "dark" && mode != "light") || rest.len() != 1 {
        eprintln!("Usage: nosd-helpers gtk-refresh [--appearance-only] (dark|light)");
        return 1;
    }
    if appearance_only {
        sync_system_appearance(mode, false);
        return 0;
    }
    let cfg = config_dir();
    if !cfg.is_dir() {
        eprintln!("Error: Config directory not found: {}", cfg.display());
        return 1;
    }
    let _ = fs::create_dir_all(cfg.join("gtk-3.0"));
    let _ = fs::create_dir_all(cfg.join("gtk-4.0"));
    let ok3 = ensure_gtk_css_import(
        &cfg.join("gtk-3.0/gtk.css"),
        &cfg.join("gtk-3.0/nosdshell.css"),
        "GTK3",
    );
    let ok4 = ensure_gtk_css_import(
        &cfg.join("gtk-4.0/gtk.css"),
        &cfg.join("gtk-4.0/nosdshell.css"),
        "GTK4",
    );
    if ok3 && ok4 {
        sync_system_appearance(mode, true);
        println!("GTK colors applied successfully");
        0
    } else {
        sync_system_appearance(mode, false);
        1
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmpdir(tag: &str) -> PathBuf {
        let d = env::temp_dir().join(format!("nosd-gtk-test-{tag}"));
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn creates_gtk_css_when_missing() {
        let d = tmpdir("create");
        let colors = d.join("nosdshell.css");
        let css = d.join("gtk.css");
        fs::write(&colors, "/* colors */").unwrap();
        assert!(ensure_gtk_css_import(&css, &colors, "GTK3"));
        let content = fs::read_to_string(&css).unwrap();
        assert!(content.contains(GTK_IMPORT));
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn keeps_existing_import_untouched() {
        let d = tmpdir("idempotent");
        let colors = d.join("nosdshell.css");
        let css = d.join("gtk.css");
        fs::write(&colors, "x").unwrap();
        fs::write(&css, "@import url(\"nosdshell.css\");\nbody{}\n").unwrap();
        assert!(ensure_gtk_css_import(&css, &colors, "GTK3"));
        let content = fs::read_to_string(&css).unwrap();
        assert_eq!(content.matches("nosdshell.css").count(), 1);
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn fails_without_colors_file() {
        let d = tmpdir("nocolors");
        let css = d.join("gtk.css");
        assert!(!ensure_gtk_css_import(&css, &d.join("nosdshell.css"), "GTK3"));
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn appends_to_plain_css() {
        let d = tmpdir("append");
        let colors = d.join("nosdshell.css");
        let css = d.join("gtk.css");
        fs::write(&colors, "x").unwrap();
        fs::write(&css, "body { color: red; }").unwrap();
        assert!(ensure_gtk_css_import(&css, &colors, "GTK4"));
        let content = fs::read_to_string(&css).unwrap();
        assert!(content.contains("body { color: red; }"));
        assert!(content.contains(GTK_IMPORT));
        let _ = fs::remove_dir_all(&d);
    }
}
