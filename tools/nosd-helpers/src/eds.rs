#![forbid(unsafe_code)]

//! Evolution Data Server calendar access over D-Bus.
//! Mirrors Scripts/python/src/calendar/{check-calendar,list-calendars,
//! calendar-events}.py, which use libecal through GObject introspection.
//!
//! Protocol (verified by introspecting a live evolution-data-server 3.60
//! over D-Bus, single persistent connection — backend objects are bound to
//! the requesting unique bus name and vanish when it disconnects):
//! - registry: org.gnome.evolution.dataserver.Sources5,
//!   /org/gnome/evolution/dataserver/SourceManager,
//!   org.freedesktop.DBus.ObjectManager.GetManagedObjects. Calendar
//!   membership comes from the `[Calendar]` group of each source's Data
//!   keyfile; display names resolve DisplayName[locale] like libedataserver.
//! - per calendar: org.gnome.evolution.dataserver.Calendar8,
//!   /org/gnome/evolution/dataserver/CalendarFactory,
//!   OpenCalendar(uid) -> (object path, bus name), then
//!   org.gnome.evolution.dataserver.Calendar.Open() and
//!   GetObjectList(sexp) -> [bare VEVENT strings].

use std::collections::HashMap;

use crate::ical;

const SOURCES_SERVICE: &str = "org.gnome.evolution.dataserver.Sources5";
const SOURCE_MANAGER_PATH: &str = "/org/gnome/evolution/dataserver/SourceManager";
const CALENDAR_SERVICE: &str = "org.gnome.evolution.dataserver.Calendar8";
const CALENDAR_FACTORY_PATH: &str = "/org/gnome/evolution/dataserver/CalendarFactory";
const SOURCE_IFACE: &str = "org.gnome.evolution.dataserver.Source";
const CAL_IFACE: &str = "org.gnome.evolution.dataserver.Calendar";
const FACTORY_IFACE: &str = "org.gnome.evolution.dataserver.CalendarFactory";

type Props = HashMap<String, zbus::zvariant::OwnedValue>;
type ManagedObjects = HashMap<zbus::zvariant::OwnedObjectPath, HashMap<String, Props>>;

fn rt() -> tokio::runtime::Runtime {
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("tokio runtime")
}

async fn session() -> Result<zbus::Connection, String> {
    zbus::Connection::session().await.map_err(|e| e.to_string())
}

async fn eds_present(conn: &zbus::Connection) -> bool {
    let proxy = match zbus::proxy::Proxy::new(
        conn,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
    )
    .await
    {
        Ok(p) => p,
        Err(_) => return false,
    };
    let names: Vec<String> = proxy.call("ListNames", &()).await.unwrap_or_default();
    names.iter().any(|n| n.starts_with("org.gnome.evolution.dataserver.Sources"))
}

async fn managed_objects(conn: &zbus::Connection) -> Result<ManagedObjects, String> {
    let proxy = zbus::proxy::Proxy::new(conn, SOURCES_SERVICE, SOURCE_MANAGER_PATH, "org.freedesktop.DBus.ObjectManager")
        .await
        .map_err(|e| e.to_string())?;
    proxy.call("GetManagedObjects", &()).await.map_err(|e| format!("EDS registry: {e}"))
}

/// Minimal keyfile reader for EDS source Data (groups, locale fallback).
fn keyfile_get(data: &str, group: &str, key: &str) -> Option<String> {
    let mut in_group = false;
    let mut plain: Option<String> = None;
    let lang = std::env::var("LANG").unwrap_or_default();
    // GLib locale fallback chain: de_DE.UTF-8 -> de_DE -> de.
    let no_codeset = lang.split(['.', '@']).next().unwrap_or("");
    let language = no_codeset.split('_').next().unwrap_or("");
    let mut local_full: Option<String> = None;
    let mut local_mid: Option<String> = None;
    let mut local_lang: Option<String> = None;
    for line in data.lines() {
        let line = line.trim();
        if line.starts_with('[') && line.ends_with(']') {
            in_group = &line[1..line.len() - 1] == group;
            continue;
        }
        if !in_group {
            continue;
        }
        let Some((k, v)) = line.split_once('=') else { continue };
        if k == key {
            plain = Some(v.to_string());
        } else if !lang.is_empty() {
            if k == format!("{key}[{lang}]") {
                local_full = Some(v.to_string());
            } else if !no_codeset.is_empty() && k == format!("{key}[{no_codeset}]") {
                local_mid = Some(v.to_string());
            } else if !language.is_empty() && k == format!("{key}[{language}]") {
                local_lang = Some(v.to_string());
            }
        }
    }
    local_full.or(local_mid).or(local_lang).or(plain)
}

fn has_group(data: &str, group: &str) -> bool {
    data.lines().any(|l| l.trim() == format!("[{group}]"))
}

fn sval(v: &zbus::zvariant::OwnedValue) -> Option<String> {
    <&str>::try_from(v).ok().map(|s| s.to_string())
}

#[derive(Debug, Clone)]
pub struct CalSource {
    pub uid: String,
    pub name: String,
}

pub fn list_calendars(objects: &ManagedObjects) -> Vec<CalSource> {
    let mut out = Vec::new();
    let mut paths: Vec<_> = objects.keys().collect();
    paths.sort_by(|a, b| a.as_str().cmp(b.as_str()));
    for path in paths {
        let ifaces = &objects[path];
        let Some(src) = ifaces.get(SOURCE_IFACE) else { continue };
        let data = match src.get("Data").and_then(sval) {
            Some(d) => d,
            None => continue,
        };
        if !has_group(&data, "Calendar") {
            continue;
        }
        if keyfile_get(&data, "Data Source", "Enabled").as_deref() != Some("true") {
            continue;
        }
        let uid = match src.get("UID").and_then(sval) {
            Some(u) => u,
            None => continue,
        };
        let name = keyfile_get(&data, "Data Source", "DisplayName").unwrap_or_else(|| uid.clone());
        out.push(CalSource { uid, name });
    }
    // list_sources() returns UID-sorted order; mirror it.
    out.sort_by(|a, b| a.uid.cmp(&b.uid));
    out
}

fn sexp_range(start: i64, end: i64) -> String {
    let zone = ical::local_zone();
    let fmt = |t: i64| {
        chrono::DateTime::from_timestamp(t, 0)
            .map(|d| d.with_timezone(&zone).format("%Y%m%dT%H%M%S").to_string())
            .unwrap_or_default()
    };
    format!("(occur-in-time-range? (make-time \"{}\") (make-time \"{}\"))", fmt(start), fmt(end))
}

fn out_event(
    calendar_name: &str,
    calendar_uid: &str,
    comp: &ical::Component,
    start: Option<i64>,
    end: Option<i64>,
    recurrent: bool,
) -> serde_json::Value {
    let summary = match &comp.summary {
        Some(s) => serde_json::Value::String(s.clone()),
        None if recurrent => serde_json::Value::String("(No title)".to_string()),
        None => serde_json::Value::Null,
    };
    let mut m = serde_json::Map::new();
    m.insert("calendar".to_string(), calendar_name.into());
    m.insert("summary".to_string(), summary);
    m.insert("start".to_string(), start.map(serde_json::Value::from).unwrap_or(serde_json::Value::Null));
    m.insert("end".to_string(), end.map(serde_json::Value::from).unwrap_or(serde_json::Value::Null));
    m.insert("location".to_string(), comp.location.clone().unwrap_or_default().into());
    m.insert("description".to_string(), comp.description.clone().unwrap_or_default().into());
    m.insert("calendar_uid".to_string(), calendar_uid.into());
    m.insert("uid".to_string(), comp.uid.clone().unwrap_or_default().into());
    serde_json::Value::Object(m)
}

async fn fetch_events(
    conn: &zbus::Connection,
    uid: &str,
    query: &str,
) -> Result<Vec<String>, String> {
    let factory = zbus::proxy::Proxy::new(conn, CALENDAR_SERVICE, CALENDAR_FACTORY_PATH, FACTORY_IFACE)
        .await
        .map_err(|e| e.to_string())?;
    let (obj, _bus): (String, String) = factory
        .call("OpenCalendar", &(uid,))
        .await
        .map_err(|e| format!("open {uid}: {e}"))?;
    let cal = zbus::proxy::Proxy::new(conn, CALENDAR_SERVICE, obj.as_str(), CAL_IFACE)
        .await
        .map_err(|e| e.to_string())?;
    let _props: Vec<String> = cal.call("Open", &()).await.map_err(|e| format!("open {uid}: {e}"))?;
    cal.call("GetObjectList", &(query,)).await.map_err(|e| format!("list {uid}: {e}"))
}

/// Convert one calendar's raw objects to event rows.
/// Returns the rows plus, on abort, the error text. Like the python
/// per-calendar try/except, rows collected before the failure are kept.
/// RDATE/EXDATE lists are ignored: the ICalGLib calls the original uses
/// (`get_rdate_list`) don't exist, so it always falls back to empty lists.
pub fn convert_calendar(
    objects: &[String],
    calendar_name: &str,
    calendar_uid: &str,
    end_time: i64,
) -> (Vec<serde_json::Value>, Option<String>) {
    let zone = ical::local_zone();
    let mut events = Vec::new();
    for ics in objects {
        for comp in ical::parse_components(ics) {
            if let Some(text) = comp.rrule_text.as_deref() {
                match ical::parse_rrule(text) {
                    Some(spec) => match ical::expand_recurrent(&comp, &spec, zone, end_time) {
                        Ok(occ) => {
                            for (s, e) in occ {
                                events.push(out_event(calendar_name, calendar_uid, &comp, s, e, true));
                            }
                        }
                        Err(e) => return (events, Some(e)),
                    },
                    // Unreachable via EDS (it strips invalid RRULEs, which
                    // then arrive as normal events); abort like the python
                    // raise path if it ever happens.
                    None => return (events, Some(format!("bad RRULE for {}", comp.uid.clone().unwrap_or_default()))),
                }
            } else {
                for (s, e) in ical::expand_normal(&comp, zone) {
                    events.push(out_event(calendar_name, calendar_uid, &comp, s, e, false));
                }
            }
        }
    }
    (events, None)
}

pub fn run_check(_args: &[String]) -> i32 {
    rt().block_on(async {
        match session().await {
            Ok(conn) if eds_present(&conn).await => println!("available"),
            Ok(_) => println!("unavailable: evolution-data-server not on session bus"),
            Err(e) => println!("unavailable: {e}"),
        }
    });
    0
}

pub fn run_calendars(_args: &[String]) -> i32 {
    let result: Result<Vec<CalSource>, String> = rt().block_on(async {
        let conn = session().await?;
        Ok(list_calendars(&managed_objects(&conn).await?))
    });
    match result {
        Ok(cals) => {
            // Byte-identical separators to python json.dumps (", ", ": ").
            let items: Vec<String> = cals
                .iter()
                .map(|c| {
                    let uid = serde_json::to_string(&c.uid).unwrap_or_default();
                    let name = serde_json::to_string(&c.name).unwrap_or_default();
                    format!("{{\"uid\": {uid}, \"name\": {name}, \"enabled\": true}}")
                })
                .collect();
            println!("[{}]", items.join(", "));
            0
        }
        Err(e) => {
            eprintln!("eds-calendars: {e}");
            1
        }
    }
}

pub fn run_events(args: &[String]) -> i32 {
    if args.len() != 2 {
        eprintln!("Usage: nosd-helpers eds-events <start_epoch> <end_epoch>");
        return 2;
    }
    let (Ok(start_time), Ok(end_time)) = (args[0].parse::<i64>(), args[1].parse::<i64>()) else {
        eprintln!("eds-events: bad epoch arguments");
        return 2;
    };
    let query = sexp_range(start_time, end_time);
    let result: Result<Vec<serde_json::Value>, String> = rt().block_on(async {
        let conn = session().await?;
        let objects = managed_objects(&conn).await?;
        let cals = list_calendars(&objects);
        let mut all = Vec::new();
        for cal in &cals {
            eprintln!("\nProcessing calendar: {}", cal.name);
            match fetch_events(&conn, &cal.uid, &query).await {
                Ok(raw) => {
                    let (mut ev, err) = convert_calendar(&raw, &cal.name, &cal.uid, end_time);
                    if let Some(e) = err {
                        eprintln!("  Error for {}: {e}", cal.name);
                    }
                    all.append(&mut ev);
                }
                Err(e) => eprintln!("  Error for {}: {e}", cal.name),
            }
        }
        // Null-safe sort; python crashes outright on a null start, Rust keeps
        // every event with nulls first (documented divergence).
        all.sort_by(|a, b| {
            a.get("start")
                .and_then(|v| v.as_i64())
                .cmp(&b.get("start").and_then(|v| v.as_i64()))
        });
        Ok(all)
    });
    match result {
        Ok(all) => {
            println!("{}", serde_json::to_string_pretty(&all).unwrap_or_default());
            0
        }
        Err(e) => {
            // Mirrors the python ImportError path: no output, nonzero exit.
            eprintln!("eds-events: {e}");
            1
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn obj(uid: &str, data: &str, enabled: bool) -> (zbus::zvariant::OwnedObjectPath, HashMap<String, Props>) {
        let path = zbus::zvariant::OwnedObjectPath::try_from(format!("/o/{uid}")).unwrap();
        let mut src = Props::new();
        src.insert("UID".to_string(), zbus::zvariant::Value::new(uid).try_into().unwrap());
        src.insert("Data".to_string(), zbus::zvariant::Value::new(data).try_into().unwrap());
        let _ = enabled;
        let mut ifaces = HashMap::new();
        ifaces.insert(SOURCE_IFACE.to_string(), src);
        (path, ifaces)
    }

    #[test]
    fn filters_calendar_enabled_only() {
        let mut objects = ManagedObjects::new();
        let (p1, i1) = obj("c1", "[Data Source]\nDisplayName=A\nEnabled=true\n\n[Calendar]\nBackendName=local\n", true);
        let (p2, i2) = obj("c2", "[Data Source]\nDisplayName=B\nEnabled=false\n\n[Calendar]\nBackendName=local\n", true);
        let (p3, i3) = obj("m1", "[Data Source]\nDisplayName=M\nEnabled=true\n", true);
        objects.insert(p1, i1);
        objects.insert(p2, i2);
        objects.insert(p3, i3);
        let cals = list_calendars(&objects);
        assert_eq!(cals.len(), 1);
        assert_eq!(cals[0].uid, "c1");
        assert_eq!(cals[0].name, "A");
    }

    #[test]
    fn locale_display_name() {
        std::env::set_var("LANG", "de_DE.UTF-8");
        assert_eq!(
            keyfile_get("[Data Source]\nDisplayName=A\nDisplayName[de]=B\n", "Data Source", "DisplayName"),
            Some("B".to_string())
        );
        std::env::set_var("LANG", "C");
        assert_eq!(
            keyfile_get("[Data Source]\nDisplayName=A\nDisplayName[de]=B\n", "Data Source", "DisplayName"),
            Some("A".to_string())
        );
    }

    #[test]
    fn sexp_format() {
        // Local-time formatting like python strftime("%Y%m%dT%H%M%S").
        let q = sexp_range(0, 60);
        assert!(q.starts_with("(occur-in-time-range? (make-time \""));
        assert!(q.contains("\") (make-time \""));
    }

    #[test]
    fn event_object_shape() {
        let comp = ical::Component {
            summary: None,
            location: Some("L".to_string()),
            description: None,
            uid: Some("u1".to_string()),
            ..Default::default()
        };
        let v = out_event("Cal", "cid", &comp, Some(10), None, false);
        assert_eq!(v.get("calendar").and_then(|v| v.as_str()), Some("Cal"));
        assert!(v.get("summary").unwrap().is_null());
        assert!(v.get("end").unwrap().is_null());
        let v2 = out_event("Cal", "cid", &comp, Some(10), Some(20), true);
        assert_eq!(v2.get("summary").and_then(|v| v.as_str()), Some("(No title)"));
    }
}
