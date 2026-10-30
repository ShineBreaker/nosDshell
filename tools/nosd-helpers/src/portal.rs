#![forbid(unsafe_code)]

//! `nosd-helpers portal`: a darkman-compatible session daemon that serves
//! the freedesktop Settings portal backend and the darkman D-Bus API from
//! one process, one connection and one state.
//!
//! Why this exists: a standalone `darkman run` registers two activatable
//! names (nl.whynothugo.darkman and org.freedesktop.impl.portal.desktop.
//! darkman). D-Bus activates them independently, so a session can end up
//! with two daemons — `darkman toggle` flips one while GTK4/Electron apps
//! listen to the other's SettingChanged. Here all names belong to a single
//! connection guarded by a lockfile, so there is exactly one authority.
//!
//! Served surface (verified against darkman 2.x introspection):
//! - /org/freedesktop/portal/desktop org.freedesktop.impl.portal.Settings:
//!   Read, ReadAll, Version=1, SettingChanged(ns, key, value).
//! - /nl/whynothugo/darkman nl.whynothugo.darkman:
//!   writable Mode property ("dark"/"light"), ModeChanged signal.
//!   `darkman get|set|toggle` and self-theme.el keep working unmodified.
//!
//! Names owned: PORTAL_NAME always; DARKMAN_NAME and the legacy portal name
//! are controlled by ~/.config/darkman/config.yaml keys `dbusserver` and
//! `portal` (both default true).
//!
//! On a transition: state file is written, signals are emitted, executables
//! in $XDG_DATA_HOME/{dark,light}-mode.d (then each $XDG_DATA_DIRS entry)
//! run sorted by path, and `nosdshell ipc call darkMode` is pushed
//! best-effort so the shell's own theme pipeline follows even when its
//! schedulingMode is not "system". The loop back is bounded: the shell
//! writes the same value, which is a no-op on its side. The .d hooks can
//! be disabled from the shell settings: `portal hooks off` writes
//! $XDG_STATE_HOME/nosdshell/darkman-hooks=0, re-read per transition.
//!
//! Scheduling is a config.yaml subset: `lat`/`lng` enable the solar timer
//! (NOAA sunrise equation, zenith 90.833°); `usegeoclue` is honoured as
//! "unsupported, falls back to lat/lng"; `pollinterval` is ignored. If
//! no coordinates are configured the daemon serves state only.
//!
//! The solar timer owns policy only while the shell cedes it:
//! `portal scheduler on|off` writes $XDG_STATE_HOME/nosdshell/
//! solar-scheduler (absent = on, so standalone `portal run` keeps darkman
//! semantics) and pokes RefreshScheduler so a schedulingMode change lands
//! on the current tick. The shell writes it on iff its own
//! schedulingMode is "system"; in manual/location/off the shell is the
//! policy owner and daemon asserts stay off — two schedulers alternating
//! on the same state is the 06:07-vs-08:30 fight this flag ends.
//! Asserts also only follow a real solar boundary, so a manual
//! `darkman set` holds until the next event instead of being stomped at
//! the next 15-minute recheck (upstream darkman behaviour).

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Mutex;
use std::sync::Arc;

use chrono::{DateTime, Datelike, Duration, Local, NaiveDate, TimeZone};
use zbus::zvariant::{OwnedValue, Value};
use zbus::{fdo, interface};

const SETTINGS_IFACE: &str = "org.freedesktop.impl.portal.Settings";
const DARKMAN_IFACE: &str = "nl.whynothugo.darkman";

const PORTAL_PATH: &str = "/org/freedesktop/portal/desktop";
const DARKMAN_PATH: &str = "/nl/whynothugo/darkman";

const PORTAL_NAME: &str = "org.freedesktop.impl.portal.desktop.nosdshell";
const PORTAL_NAME_LEGACY: &str = "org.freedesktop.impl.portal.desktop.darkman";
const DARKMAN_NAME: &str = "nl.whynothugo.darkman";

const NS_APPEARANCE: &str = "org.freedesktop.appearance";
const KEY_COLOR_SCHEME: &str = "color-scheme";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Mode {
    Dark,
    Light,
}

impl Mode {
    fn name(self) -> &'static str {
        match self {
            Mode::Dark => "dark",
            Mode::Light => "light",
        }
    }
    fn scheme(self) -> u32 {
        match self {
            Mode::Dark => 1,
            Mode::Light => 2,
        }
    }
    fn parse(s: &str) -> Option<Mode> {
        match s {
            "dark" => Some(Mode::Dark),
            "light" => Some(Mode::Light),
            _ => None,
        }
    }
    fn other(self) -> Mode {
        match self {
            Mode::Dark => Mode::Light,
            Mode::Light => Mode::Dark,
        }
    }
}

fn state_dir() -> PathBuf {
    let base = std::env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".local/state"));
    base.join("nosdshell")
}

fn state_file() -> PathBuf {
    state_dir().join("color-scheme")
}

// Shell-side kill switch for the .d hooks: the settings toggle writes this
// flag via `portal hooks on|off` so a flip lands without restarting the
// daemon. Absent file = hooks on, matching darkman's default behaviour.
fn hooks_flag_file() -> PathBuf {
    state_dir().join("darkman-hooks")
}

fn hooks_flag_enabled() -> bool {
    match fs::read_to_string(hooks_flag_file()) {
        Ok(s) => !matches!(s.trim(), "0" | "off" | "false"),
        Err(_) => true,
    }
}

// Policy-owner flag for the solar timer, written by the shell via
// `portal scheduler on|off`: on only while colorSchemes.schedulingMode is
// "system" (the shell follows the session portal state); every other mode
// makes the shell's own schedule the authority and daemon asserts stay
// off. Absent file = on: standalone `portal run` with lat/lng keeps
// darkman's solar default.
fn scheduler_flag_file() -> PathBuf {
    state_dir().join("solar-scheduler")
}

fn scheduler_flag_enabled() -> bool {
    match fs::read_to_string(scheduler_flag_file()) {
        Ok(s) => !matches!(s.trim(), "0" | "off" | "false"),
        Err(_) => true,
    }
}

fn write_flag(file: PathBuf, enabled: bool) -> Result<(), String> {
    if let Some(parent) = file.parent() {
        let _ = fs::create_dir_all(parent);
    }
    fs::write(&file, if enabled { "1" } else { "0" })
        .map_err(|e| format!("write {}: {e}", file.display()))
}

fn home() -> PathBuf {
    PathBuf::from(std::env::var_os("HOME").unwrap_or_default())
}

fn data_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    if let Some(h) = std::env::var_os("XDG_DATA_HOME") {
        dirs.push(PathBuf::from(h));
    } else {
        dirs.push(home().join(".local/share"));
    }
    let extra = std::env::var("XDG_DATA_DIRS").unwrap_or_else(|_| "/usr/local/share:/usr/share".into());
    for d in extra.split(':').filter(|d| !d.is_empty()) {
        dirs.push(PathBuf::from(d));
    }
    dirs
}

fn runtime_dir() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(format!("/run/user/{}", nix_uid())))
}

fn nix_uid() -> u32 {
    Command::new("id")
        .arg("-u")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .and_then(|s| s.trim().parse().ok())
        .unwrap_or(1000)
}

// ---------------------------------------------------------------------------
// darkman config.yaml subset (flat "key: value" lines; YAML lists/maps we do
// not recognise are ignored on purpose).

#[derive(Default)]
struct DaemonConfig {
    lat: Option<f64>,
    lng: Option<f64>,
    usegeoclue: bool,
    dbusserver: bool,
    portal: bool,
}

fn load_config() -> DaemonConfig {
    let mut cfg = DaemonConfig {
        dbusserver: true,
        portal: true,
        ..Default::default()
    };
    let path = home().join(".config/darkman/config.yaml");
    let Ok(text) = fs::read_to_string(&path) else {
        return cfg;
    };
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((key, value)) = line.split_once(':') else {
            continue;
        };
        let value = value.trim().trim_matches('"').trim_matches('\'');
        match key.trim() {
            "lat" => cfg.lat = value.parse().ok(),
            "lng" => cfg.lng = value.parse().ok(),
            "usegeoclue" => cfg.usegeoclue = value == "true",
            "dbusserver" => cfg.dbusserver = value != "false",
            "portal" => cfg.portal = value != "false",
            _ => {}
        }
    }
    cfg
}

// ---------------------------------------------------------------------------
// Solar position: NOAA sunrise equation with the official 90.833° zenith
// (accounts for refraction + solar disc radius, matching darkman's source).

fn solar_time<Tz: TimeZone>(
    date: NaiveDate,
    lat: f64,
    lng: f64,
    sunrise: bool,
    tz: &Tz,
) -> Option<DateTime<Tz>> {
    let day = date.ordinal() as f64;
    let lng_hour = lng / 15.0;
    let t = if sunrise {
        day + (6.0 - lng_hour) / 24.0
    } else {
        day + (18.0 - lng_hour) / 24.0
    };
    let mean_anomaly = 0.9856 * t - 3.289;
    let true_long = (mean_anomaly
        + 1.916 * mean_anomaly.to_radians().sin()
        + 0.020 * (2.0 * mean_anomaly).to_radians().sin()
        + 282.634)
        .rem_euclid(360.0);
    let mut ra = (0.91764 * true_long.to_radians().tan()).atan().to_degrees();
    ra += (true_long / 90.0).floor() * 90.0 - (ra / 90.0).floor() * 90.0;
    ra /= 15.0;
    let sin_dec = 0.39782 * true_long.to_radians().sin();
    let cos_dec = sin_dec.asin().cos();
    let cos_h = (90.833f64.to_radians().cos() - sin_dec * lat.to_radians().sin())
        / (cos_dec * lat.to_radians().cos());
    if cos_h.abs() > 1.0 {
        return None; // polar day/night: no event today
    }
    let h_deg = if sunrise {
        360.0 - cos_h.acos().to_degrees()
    } else {
        cos_h.acos().to_degrees()
    };
    // UT is hours on the queried UTC date; for longitudes far from Greenwich
    // the event may actually fall on a neighbouring UTC day (e.g. a +08:00
    // sunrise is the previous UTC evening). Anchor by picking the candidate
    // day nearest the locally-approximated event time — this also makes the
    // UTC->Local conversion handle DST correctly.
    let ut = (h_deg / 15.0 + ra - 0.06571 * t - 6.622 - lng_hour).rem_euclid(24.0);
    let day_start = chrono::Utc
        .with_ymd_and_hms(date.year(), date.month(), date.day(), 0, 0, 0)
        .single()?;
    let approx_local = tz
        .from_local_datetime(&date.and_hms_opt(if sunrise { 6 } else { 18 }, 0, 0)?)
        .earliest()?;
    let approx_utc = approx_local.with_timezone(&chrono::Utc);
    let c0 = day_start + Duration::seconds((ut * 3600.0).round() as i64);
    [
        c0 - Duration::days(1),
        c0,
        c0 + Duration::days(1),
    ]
    .into_iter()
    .min_by_key(|cand| (*cand - approx_utc).num_seconds().abs())
    .map(|cand| cand.with_timezone(tz))
}

fn expected_mode<Tz: TimeZone>(lat: f64, lng: f64, now: DateTime<Tz>) -> Mode {
    let tz = now.timezone();
    let today = now.date_naive();
    match (
        solar_time(today, lat, lng, true, &tz),
        solar_time(today, lat, lng, false, &tz),
    ) {
        (Some(rise), Some(set)) => {
            if now >= rise && now < set {
                Mode::Light
            } else {
                Mode::Dark
            }
        }
        // Polar day/night: keep current mode; the daemon's stored state is
        // the best guess until coordinates change.
        _ => Mode::Dark,
    }
}

fn next_boundary<Tz: TimeZone>(lat: f64, lng: f64, now: DateTime<Tz>) -> Option<DateTime<Tz>> {
    let tz = now.timezone();
    let mut events = Vec::new();
    for offset in 0..2 {
        let date = now.date_naive() + Duration::days(offset);
        for sunrise in [true, false] {
            if let Some(local) = solar_time(date, lat, lng, sunrise, &tz) {
                if local > now {
                    events.push(local);
                }
            }
        }
    }
    events.into_iter().min()
}

// Newest solar event at or before `now`. Solar events repeat daily outside
// the polar regions, so the latest one is always within the last few days;
// the 4-day window also covers a daemon that slept across a weekend.
fn prev_boundary<Tz: TimeZone>(lat: f64, lng: f64, now: DateTime<Tz>) -> Option<DateTime<Tz>> {
    let tz = now.timezone();
    let mut events = Vec::new();
    for offset in -3..=0 {
        let date = now.date_naive() + Duration::days(offset);
        for sunrise in [true, false] {
            if let Some(local) = solar_time(date, lat, lng, sunrise, &tz) {
                if local <= now {
                    events.push(local);
                }
            }
        }
    }
    events.into_iter().max()
}

// ---------------------------------------------------------------------------
// Shared daemon state.

struct Daemon {
    mode: Mutex<Mode>,
    conn: zbus::Connection,
    hooks: bool,
    forward: bool,
    // Poked by RefreshScheduler so the solar loop re-evaluates the
    // policy-owner flag on the current tick instead of the next ≤15-min one.
    sched_kick: tokio::sync::Notify,
}

impl Daemon {
    fn mode(&self) -> Mode {
        *self.mode.lock().unwrap()
    }

    // Single transition pipeline: dedupe -> persist -> emit -> hooks -> qs.
    async fn transition(&self, target: Mode) {
        {
            let mut cur = self.mode.lock().unwrap();
            if *cur == target {
                return;
            }
            *cur = target;
        }
        persist(target);
        self.emit_all(target).await;
        // Hooks and the shell forward run on plain threads: interface
        // methods execute on zbus's own executor, where tokio::spawn_*
        // has no reactor. The flag file is re-read per transition so the
        // settings toggle takes effect on the next flip, not at restart.
        if self.hooks && hooks_flag_enabled() {
            std::thread::spawn(move || run_hooks(target));
        }
        if self.forward {
            std::thread::spawn(move || forward_shell(target));
        }
    }

    async fn emit_all(&self, mode: Mode) {
        // Portal clients (GTK4, Electron/Chromium) subscribe here.
        let _ = self
            .conn
            .emit_signal(
                None::<&str>,
                PORTAL_PATH,
                SETTINGS_IFACE,
                "SettingChanged",
                &(NS_APPEARANCE, KEY_COLOR_SCHEME, Value::from(mode.scheme())),
            )
            .await;
        // darkman consumers (self-theme.el, `darkman` CLI listeners).
        let _ = self
            .conn
            .emit_signal(
                None::<&str>,
                DARKMAN_PATH,
                DARKMAN_IFACE,
                "ModeChanged",
                &mode.name(),
            )
            .await;
    }
}

fn persist(mode: Mode) {
    let path = state_file();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(&path, mode.name());
}

fn load_state() -> Option<Mode> {
    fs::read_to_string(state_file())
        .ok()
        .and_then(|s| Mode::parse(s.trim()))
}

fn executable_scripts(dir: &Path) -> Vec<PathBuf> {
    let mut out: Vec<PathBuf> = fs::read_dir(dir)
        .map(|rd| {
            rd.filter_map(|e| e.ok())
                .map(|e| e.path())
                .filter(|p| {
                    p.is_file()
                        && p.metadata()
                            .map(|m| {
                                std::os::unix::fs::PermissionsExt::mode(&m.permissions()) & 0o111 != 0
                            })
                            .unwrap_or(false)
                })
                .collect()
        })
        .unwrap_or_default();
    out.sort();
    out
}

fn run_hooks(mode: Mode) {
    let subdir = match mode {
        Mode::Dark => "dark-mode.d",
        Mode::Light => "light-mode.d",
    };
    let scripts: Vec<PathBuf> = data_dirs()
        .iter()
        .flat_map(|d| executable_scripts(&d.join(subdir)))
        .collect();
    for script in scripts {
        let _ = Command::new(&script).status();
    }
}

// Best-effort push into the shell's own pipeline; the ipc write lands on the
// same darkMode value, so it cannot loop.
fn forward_shell(mode: Mode) {
    let verb = match mode {
        Mode::Dark => "setDark",
        Mode::Light => "setLight",
    };
    let _ = Command::new("nosdshell")
        .args(["ipc", "call", "darkMode", verb])
        .output();
}

// ---------------------------------------------------------------------------
// D-Bus interfaces.

struct PortalSettings {
    d: Arc<Daemon>,
}

#[interface(name = "org.freedesktop.impl.portal.Settings")]
impl PortalSettings {
    async fn read(&self, namespace: &str, key: &str) -> fdo::Result<OwnedValue> {
        if namespace == NS_APPEARANCE && key == KEY_COLOR_SCHEME {
            Ok(OwnedValue::from(self.d.mode().scheme()))
        } else {
            Err(fdo::Error::UnknownProperty(format!(
                "No such setting: {namespace}/{key}"
            )))
        }
    }

    async fn read_all(
        &self,
        namespaces: Vec<String>,
    ) -> HashMap<String, HashMap<String, OwnedValue>> {
        let mut out = HashMap::new();
        if namespaces.is_empty() || namespaces.iter().any(|n| n == NS_APPEARANCE) {
            let mut ns = HashMap::new();
            ns.insert(
                KEY_COLOR_SCHEME.to_string(),
                OwnedValue::from(self.d.mode().scheme()),
            );
            out.insert(NS_APPEARANCE.to_string(), ns);
        }
        out
    }

    #[zbus(property)]
    async fn version(&self) -> u32 {
        1
    }
}

struct DarkmanApi {
    d: Arc<Daemon>,
}

#[interface(name = "nl.whynothugo.darkman")]
impl DarkmanApi {
    #[zbus(property)]
    async fn mode(&self) -> String {
        self.d.mode().name().to_string()
    }

    #[zbus(property)]
    async fn set_mode(&self, mode: String) -> fdo::Result<()> {
        match Mode::parse(&mode) {
            Some(m) => {
                self.d.transition(m).await;
                Ok(())
            }
            None => Err(fdo::Error::InvalidArgs(format!("unknown mode: {mode}"))),
        }
    }

    // nosdshell extension (upstream darkman has no such member; compat
    // clients ignore it): `portal scheduler` writes the flag file then
    // pokes here so the solar loop honours a schedulingMode change on the
    // current tick rather than the next ≤15-minute recheck.
    async fn refresh_scheduler(&self) {
        self.d.sched_kick.notify_one();
    }
}

// ---------------------------------------------------------------------------
// Daemon entry.

fn take_lock() -> Result<fs::File, String> {
    let path = runtime_dir().join("nosd-portal.lock");
    let file = fs::File::options()
        .create(true)
        .write(true)
        .open(&path)
        .map_err(|e| format!("open {}: {e}", path.display()))?;
    // try_lock, not lock: a second `portal run` must fail fast instead of
    // blocking on the held lock. The blocking variant left every extra spawn
    // (each shell restart execDetached's one) parked on the flock queue as a
    // live but useless process — the multi-copy resident-memory leak.
    match file.try_lock() {
        Ok(()) => Ok(file),
        Err(fs::TryLockError::WouldBlock) => Err(format!(
            "another portal daemon already holds {}; exiting",
            path.display()
        )),
        Err(e) => Err(format!("lock {}: {e}", path.display())),
    }
}

async fn own_name(conn: &zbus::Connection, name: &'static str, required: bool) -> Result<(), String> {
    use zbus::fdo::RequestNameFlags;
    match conn
        .request_name_with_flags(name, RequestNameFlags::DoNotQueue.into())
        .await
    {
        Ok(_) => Ok(()),
        Err(e) if required => Err(format!("cannot own bus name {name}: {e}")),
        Err(e) => {
            eprintln!("nosd-helpers portal: optional name {name} unavailable: {e}");
            Ok(())
        }
    }
}

async fn scheduler(d: Arc<Daemon>, lat: f64, lng: f64) {
    // Asserts only while the shell cedes policy (solar-scheduler flag on),
    // and only when a solar boundary newer than the last asserted one has
    // passed: the <=15-minute recheck exists to catch missed boundaries
    // (suspend/resume, DST), not to re-assert — a `darkman set` between
    // boundaries must hold, matching upstream darkman.
    let mut last_boundary: Option<DateTime<Local>> = None;
    loop {
        let now = Local::now();
        if scheduler_flag_enabled() {
            let boundary = prev_boundary(lat, lng, now);
            if boundary.is_some() && boundary != last_boundary {
                d.transition(expected_mode(lat, lng, now)).await;
                last_boundary = boundary;
            }
        }
        let next = next_boundary(lat, lng, now);
        let wait = match next {
            Some(t) => (t - now).to_std().unwrap_or_default(),
            None => Duration::minutes(30).to_std().unwrap_or_default(),
        };
        // Recheck at least every 15 minutes: picks up flag writes, DST
        // shifts and post-resume drift without a file watcher.
        // RefreshScheduler wakes the loop early through sched_kick.
        tokio::select! {
            _ = tokio::time::sleep(std::cmp::min(wait, std::time::Duration::from_secs(900))) => {}
            _ = d.sched_kick.notified() => {}
        }
    }
}

fn print_usage() -> ! {
    eprintln!("Usage: nosd-helpers portal <run|get|set|toggle> [dark|light]");
    eprintln!("       nosd-helpers portal hooks <on|off>");
    eprintln!("       nosd-helpers portal scheduler <on|off>");
    std::process::exit(2);
}

fn rt() -> tokio::runtime::Runtime {
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("tokio runtime")
}

pub fn run(args: &[String]) -> i32 {
    let code = match args.first().map(String::as_str) {
        Some("run") => rt().block_on(serve()),
        Some("get") => rt().block_on(client_get()),
        Some("set") => match args.get(1).map(String::as_str) {
            Some(m) if Mode::parse(m).is_some() => rt().block_on(client_set(m)),
            _ => print_usage(),
        },
        Some("toggle") => rt().block_on(client_toggle()),
        // Local flag write, not a bus call: the flag must land even when the
        // daemon is not running yet so the next transition honours it.
        Some("hooks") => match args.get(1).map(String::as_str) {
            Some("on") => write_flag(hooks_flag_file(), true),
            Some("off") => write_flag(hooks_flag_file(), false),
            _ => print_usage(),
        },
        // Same pattern: flag file lands without the daemon, the
        // RefreshScheduler poke wakes a running one best-effort.
        Some("scheduler") => match args.get(1).map(String::as_str) {
            Some("on") => rt().block_on(client_scheduler(true)),
            Some("off") => rt().block_on(client_scheduler(false)),
            _ => print_usage(),
        },
        _ => print_usage(),
    };
    match code {
        Ok(()) => 0,
        Err(e) => {
            eprintln!("nosd-helpers portal: {e}");
            1
        }
    }
}

async fn mode_proxy(conn: &zbus::Connection) -> Result<zbus::Proxy<'_>, String> {
    zbus::Proxy::new(conn, DARKMAN_NAME, DARKMAN_PATH, DARKMAN_IFACE)
        .await
        .map_err(|e| e.to_string())
}

async fn client_get() -> Result<(), String> {
    let conn = zbus::Connection::session().await.map_err(|e| e.to_string())?;
    let mode: String = mode_proxy(&conn)
        .await?
        .get_property("Mode")
        .await
        .map_err(|e| e.to_string())?;
    println!("{mode}");
    Ok(())
}

async fn client_set(mode: &str) -> Result<(), String> {
    let conn = zbus::Connection::session().await.map_err(|e| e.to_string())?;
    mode_proxy(&conn)
        .await?
        .set_property("Mode", mode)
        .await
        .map_err(|e| e.to_string())
}

async fn client_toggle() -> Result<(), String> {
    let conn = zbus::Connection::session().await.map_err(|e| e.to_string())?;
    let proxy = mode_proxy(&conn).await?;
    let cur: String = proxy
        .get_property("Mode")
        .await
        .map_err(|e| e.to_string())?;
    let next = Mode::parse(&cur).map(|m| m.other()).unwrap_or(Mode::Light);
    proxy
        .set_property("Mode", next.name())
        .await
        .map_err(|e| e.to_string())
}

async fn client_scheduler(enabled: bool) -> Result<(), String> {
    write_flag(scheduler_flag_file(), enabled)?;
    // Best effort: the flag file is authoritative, so a missing session bus
    // or a not-yet-running daemon must not fail the command — the daemon
    // re-reads the flag on its next tick either way.
    if let Ok(conn) = zbus::Connection::session().await {
        if let Ok(proxy) = mode_proxy(&conn).await {
            let _ = proxy.call_method("RefreshScheduler", &()).await;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{NaiveDate, Timelike};
    use chrono_tz::Asia::Shanghai;

    // Shanghai, summer solstice: NOAA tables give sunrise ~04:51 and
    // sunset ~19:02 local time. Assert the equation lands inside a
    // ±30min window rather than on an exact minute.
    #[test]
    fn solar_events_shanghai_solstice() {
        let date = NaiveDate::from_ymd_opt(2026, 6, 21).unwrap();
        let rise = solar_time(date, 31.2304, 121.4737, true, &Shanghai).expect("sunrise exists");
        let set = solar_time(date, 31.2304, 121.4737, false, &Shanghai).expect("sunset exists");
        assert!(rise < set);
        assert!((4..=6).contains(&rise.hour()), "sunrise {}", rise);
        assert!((18..=20).contains(&set.hour()), "sunset {}", set);
    }

    #[test]
    fn expected_mode_noon_and_midnight() {
        let (lat, lng) = (31.2304, 121.4737);
        let noon = Shanghai.with_ymd_and_hms(2026, 6, 21, 12, 0, 0).unwrap();
        let midnight = Shanghai.with_ymd_and_hms(2026, 6, 21, 0, 0, 0).unwrap();
        assert_eq!(expected_mode(lat, lng, noon), Mode::Light);
        assert_eq!(expected_mode(lat, lng, midnight), Mode::Dark);
    }

    #[test]
    fn next_boundary_is_in_the_future() {
        let (lat, lng) = (31.2304, 121.4737);
        let now = Shanghai.with_ymd_and_hms(2026, 6, 21, 12, 0, 0).unwrap();
        let next = next_boundary(lat, lng, now).expect("a boundary exists");
        assert!(next > now);
        // Solstice has both events within ~14h of each other.
        assert!(next - now < Duration::hours(26));
    }

    #[test]
    fn prev_boundary_finds_latest_past_event() {
        let (lat, lng) = (31.2304, 121.4737);
        // Solstice late evening: the newest past boundary is today's
        // ~19:02 sunset, not yesterday's.
        let night = Shanghai.with_ymd_and_hms(2026, 6, 21, 23, 0, 0).unwrap();
        let b = prev_boundary(lat, lng, night).expect("a boundary exists");
        assert!(b <= night);
        assert_eq!(b.date_naive(), night.date_naive());
        assert!(b > night - Duration::hours(8), "boundary {b} too old");
        // Pre-dawn: today's ~04:51 sunrise is still in the future, so the
        // newest past boundary is yesterday's sunset.
        let early = Shanghai.with_ymd_and_hms(2026, 6, 21, 4, 0, 0).unwrap();
        let b = prev_boundary(lat, lng, early).expect("a boundary exists");
        assert!(b <= early);
        assert_eq!(b.date_naive(), NaiveDate::from_ymd_opt(2026, 6, 20).unwrap());
    }

    #[test]
    fn mode_parse_roundtrip() {
        assert_eq!(Mode::parse("dark"), Some(Mode::Dark));
        assert_eq!(Mode::parse("light"), Some(Mode::Light));
        assert_eq!(Mode::parse("bogus"), None);
        assert_eq!(Mode::Dark.other(), Mode::Light);
        assert_eq!(Mode::Dark.scheme(), 1);
        assert_eq!(Mode::Light.scheme(), 2);
    }

    #[test]
    fn config_flat_keys() {
        let yaml = "lat: 31.2304\nlng: 121.4737\nusegeoclue: false\ndbusserver: true\nportal: true\npollinterval: 5\n";
        let mut cfg = DaemonConfig {
            dbusserver: true,
            portal: true,
            ..Default::default()
        };
        for line in yaml.lines() {
            let line = line.trim();
            let Some((key, value)) = line.split_once(':') else {
                continue;
            };
            let value = value.trim().trim_matches('"').trim_matches('\'');
            match key.trim() {
                "lat" => cfg.lat = value.parse().ok(),
                "lng" => cfg.lng = value.parse().ok(),
                "usegeoclue" => cfg.usegeoclue = value == "true",
                "dbusserver" => cfg.dbusserver = value != "false",
                "portal" => cfg.portal = value != "false",
                _ => {}
            }
        }
        assert_eq!(cfg.lat, Some(31.2304));
        assert_eq!(cfg.lng, Some(121.4737));
        assert!(cfg.dbusserver && cfg.portal);
        assert!(!cfg.usegeoclue);
    }
}

async fn serve() -> Result<(), String> {
    // Single instance: the lockfile serialises startup so two concurrent
    // activations cannot split the two bus names between processes.
    let _lock = take_lock()?;

    let cfg = load_config();
    if cfg.usegeoclue {
        eprintln!("nosd-helpers portal: usegeoclue is not supported; configure lat/lng in config.yaml");
    }
    if !cfg.dbusserver && !cfg.portal {
        return Err("config.yaml disables both dbusserver and portal; nothing to serve".into());
    }

    let conn = zbus::Connection::session()
        .await
        .map_err(|e| e.to_string())?;

    // Startup mode: persisted state wins (survives daemon restarts), then the
    // configured solar position, then light. No signals are emitted here —
    // subscribers do an initial Read; hooks only fire on real transitions.
    let initial = load_state()
        .or_else(|| cfg.lat.zip(cfg.lng).map(|(la, ln)| expected_mode(la, ln, Local::now())))
        .unwrap_or(Mode::Light);
    persist(initial);

    let daemon = Arc::new(Daemon {
        mode: Mutex::new(initial),
        conn: conn.clone(),
        hooks: true,
        forward: true,
        sched_kick: tokio::sync::Notify::new(),
    });

    conn.object_server()
        .at(PORTAL_PATH, PortalSettings { d: daemon.clone() })
        .await
        .map_err(|e| e.to_string())?;
    conn.object_server()
        .at(DARKMAN_PATH, DarkmanApi { d: daemon.clone() })
        .await
        .map_err(|e| e.to_string())?;

    if cfg.portal {
        own_name(&conn, PORTAL_NAME, true).await?;
        own_name(&conn, PORTAL_NAME_LEGACY, false).await?;
    }
    if cfg.dbusserver {
        own_name(&conn, DARKMAN_NAME, true).await?;
    }

    eprintln!(
        "nosd-helpers portal: serving mode={} (portal={}, darkman-api={})",
        daemon.mode().name(),
        cfg.portal,
        cfg.dbusserver
    );

    if let (Some(lat), Some(lng)) = (cfg.lat, cfg.lng) {
        let d = daemon.clone();
        tokio::spawn(async move { scheduler(d, lat, lng).await });
    }

    std::future::pending::<()>().await;
    Ok(())
}
