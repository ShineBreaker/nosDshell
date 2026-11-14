#![forbid(unsafe_code)]

//! GTK refresh helper.
//! Ported from the removed Scripts/python/src/theming/gtk-refresh.py:
//! ensure gtk.css imports nosd.css (GTK3/4), then push the
//! light/dark preference via gsettings (dconf fallback).

use std::env;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;

// Palette file written by the `gtk` color template (TemplateRegistry.qml,
// outputs ~/.config/gtk-{3,4}.0/nosd.css). The two sides live in different
// languages, so this name is a cross-file contract: change it here and there
// must be changed together, or the import is never wired up.
const GTK_IMPORT: &str = "@import url(\"nosd.css\");";

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

/// Append the nosd.css import to gtk.css unless already present.
/// Returns false when the colors file is missing.
pub fn ensure_gtk_css_import(gtk_css: &Path, colors_file: &Path, label: &str) -> bool {
    if !colors_file.exists() {
        eprintln!("Error: {label} nosd.css not found at {}", colors_file.display());
        return false;
    }
    if gtk_css.exists() || gtk_css.is_symlink() {
        let content = fs::read_to_string(gtk_css).unwrap_or_default();
        if content.contains("nosd.css") && content.contains("@import") {
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
        println!("Created {label} gtk.css with nosd.css import");
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
    println!("Appended {label} nosd.css import to gtk.css");
}

/// The GTK theme name is read from the standard GTK settings file
/// (`gtk-theme-name` in ~/.config/gtk-{3,4}.0/settings.ini). That file is
/// written by whatever actually manages the desktop theme — darkman's
/// set-theme.sh, a desktop's appearance panel, or the user by hand — so this
/// works for people who do not use darkman at all, unlike reading darkman's
/// own config.json. Falls back to the nosd-app-themes defaults when the key is
/// missing, so a bare system still gets a sensible theme.
fn theme_for_mode(mode: &str) -> String {
    for version in ["gtk-3.0", "gtk-4.0"] {
        let path = config_dir().join(version).join("settings.ini");
        if let Ok(text) = fs::read_to_string(&path) {
            if let Some(name) = read_gtk_theme_name(&text) {
                return name;
            }
        }
    }
    if mode == "light" { "deepin".to_string() } else { "deepin-dark".to_string() }
}

/// Pull `gtk-theme-name` out of a GTK settings.ini body.
fn read_gtk_theme_name(ini: &str) -> Option<String> {
    for line in ini.lines() {
        let line = line.trim();
        if line.starts_with('#') || line.starts_with(';') {
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            if key.trim() == "gtk-theme-name" {
                let name = value.trim().trim_matches(|c| c == '"' || c == '\'');
                if !name.is_empty() {
                    return Some(name.to_string());
                }
            }
        }
    }
    None
}

fn sync_system_appearance(mode: &str, update_gtk_theme: bool) {
    let has_gsettings = on_path("gsettings");
    let has_dconf = on_path("dconf");
    if !has_gsettings && !has_dconf {
        println!("No gsettings or dconf found, skip system appearance sync");
        return;
    }
    let target_theme = theme_for_mode(mode);
    let theme_available = update_gtk_theme && theme_exists(&target_theme);
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
                        &["set", "org.gnome.desktop.interface", "gtk-theme", &target_theme],
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
        &cfg.join("gtk-3.0/nosd.css"),
        "GTK3",
    );
    let ok4 = ensure_gtk_css_import(
        &cfg.join("gtk-4.0/gtk.css"),
        &cfg.join("gtk-4.0/nosd.css"),
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
        let colors = d.join("nosd.css");
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
        let colors = d.join("nosd.css");
        let css = d.join("gtk.css");
        fs::write(&colors, "x").unwrap();
        fs::write(&css, "@import url(\"nosd.css\");\nbody{}\n").unwrap();
        assert!(ensure_gtk_css_import(&css, &colors, "GTK3"));
        let content = fs::read_to_string(&css).unwrap();
        assert_eq!(content.matches("nosd.css").count(), 1);
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn fails_without_colors_file() {
        let d = tmpdir("nocolors");
        let css = d.join("gtk.css");
        assert!(!ensure_gtk_css_import(&css, &d.join("nosd.css"), "GTK3"));
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn appends_to_plain_css() {
        let d = tmpdir("append");
        let colors = d.join("nosd.css");
        let css = d.join("gtk.css");
        fs::write(&colors, "x").unwrap();
        fs::write(&css, "body { color: red; }").unwrap();
        assert!(ensure_gtk_css_import(&css, &colors, "GTK4"));
        let content = fs::read_to_string(&css).unwrap();
        assert!(content.contains("body { color: red; }"));
        assert!(content.contains(GTK_IMPORT));
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn reads_gtk_theme_name_from_settings_ini() {
        let ini = "# comment\n[Settings]\ngtk-icon-theme-name=Papirus\ngtk-theme-name=deepin-dark\n";
        assert_eq!(read_gtk_theme_name(ini).as_deref(), Some("deepin-dark"));
    }

    #[test]
    fn tolerates_quoted_theme_name() {
        assert_eq!(read_gtk_theme_name("gtk-theme-name = \"deepin\"\n").as_deref(), Some("deepin"));
    }

    #[test]
    fn ignores_missing_or_empty_theme_name() {
        assert_eq!(read_gtk_theme_name("[Settings]\ngtk-icon-theme-name=Papirus\n"), None);
        assert_eq!(read_gtk_theme_name("[Settings]\ngtk-theme-name=\n"), None);
    }

    // Runs alone (env vars are process-global) with the temp dir as
    // XDG_CONFIG_HOME so it never touches the real user config.
    #[test]
    fn theme_for_mode_reads_settings_ini_and_falls_back() {
        let base = tmpdir("theme_mode");
        let gtk = base.join("gtk-3.0");
        fs::create_dir_all(&gtk).unwrap();
        fs::write(gtk.join("settings.ini"), "[Settings]\ngtk-theme-name=deepin-dark\n").unwrap();

        let old = env::var_os("XDG_CONFIG_HOME");
        env::set_var("XDG_CONFIG_HOME", &base);
        let from_ini = theme_for_mode("light"); // literal value, mode only affects fallback
        fs::remove_file(gtk.join("settings.ini")).unwrap();
        let dark_fallback = theme_for_mode("dark");
        let light_fallback = theme_for_mode("light");
        match old {
            Some(v) => env::set_var("XDG_CONFIG_HOME", v),
            None => env::remove_var("XDG_CONFIG_HOME"),
        }

        assert_eq!(from_ini, "deepin-dark");
        assert_eq!(dark_fallback, "deepin-dark");
        assert_eq!(light_fallback, "deepin");
        let _ = fs::remove_dir_all(&base);
    }
}
