#![forbid(unsafe_code)]

//! Wayland 合成器模糊能力探测。
//!
//! 连接 `$WAYLAND_DISPLAY` 并枚举 registry globals，输出一行 JSON：
//! `{"compositor_blur": <bool>, "globals": [...]}`。
//! `compositor_blur` 当且仅当存在 `ext_background_effect_manager_v1`
//! 接口（DESIGN.md §1.2/§4.1：合成器无该接口时蒙版按无模糊取 0.8）。

use wayland_client::globals::{GlobalListContents, registry_queue_init};
use wayland_client::protocol::wl_registry;
use wayland_client::{Connection, Dispatch, QueueHandle};

/// 存在即表示合成器支持背景模糊的全局接口名。
pub const BLUR_GLOBAL: &str = "ext_background_effect_manager_v1";

struct State;

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for State {
    fn event(
        _state: &mut Self,
        _proxy: &wl_registry::WlRegistry,
        _event: wl_registry::Event,
        _data: &GlobalListContents,
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
    }
}

/// 全局接口名列表 → 单行 JSON（纯函数，便于无合成器测试）。
pub fn render_json(names: &[String]) -> String {
    let blur = names.iter().any(|n| n == BLUR_GLOBAL);
    serde_json::json!({ "compositor_blur": blur, "globals": names }).to_string()
}

fn probe() -> Result<String, String> {
    let display = std::env::var("WAYLAND_DISPLAY").map_err(|_| {
        "wl-probe: WAYLAND_DISPLAY is not set, cannot connect to a Wayland compositor".to_string()
    })?;
    let conn = Connection::connect_to_env().map_err(|e| {
        format!("wl-probe: failed to connect to Wayland display {display:?}: {e}")
    })?;
    let (globals, mut queue) = registry_queue_init::<State>(&conn)
        .map_err(|e| format!("wl-probe: failed to enumerate Wayland registry: {e}"))?;
    let mut state = State;
    queue
        .roundtrip(&mut state)
        .map_err(|e| format!("wl-probe: Wayland roundtrip failed: {e}"))?;
    let names: Vec<String> = globals
        .contents()
        .clone_list()
        .iter()
        .map(|g| g.interface.clone())
        .collect();
    Ok(render_json(&names))
}

pub fn run(args: &[String]) -> i32 {
    if !args.is_empty() {
        eprintln!("Usage: nosd-helpers wl-probe");
        return 1;
    }
    match probe() {
        Ok(line) => {
            println!("{line}");
            0
        }
        Err(msg) => {
            eprintln!("{msg}");
            1
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn names(list: &[&str]) -> Vec<String> {
        list.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn blur_true_when_effect_manager_present() {
        let out = render_json(&names(&["wl_compositor", BLUR_GLOBAL, "wl_shm"]));
        let v: serde_json::Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["compositor_blur"], true);
        assert_eq!(v["globals"], serde_json::json!(["wl_compositor", BLUR_GLOBAL, "wl_shm"]));
    }

    #[test]
    fn blur_false_without_effect_manager() {
        let out = render_json(&names(&["wl_compositor", "wl_shm"]));
        let v: serde_json::Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["compositor_blur"], false);
        assert_eq!(v["globals"], serde_json::json!(["wl_compositor", "wl_shm"]));
    }

    #[test]
    fn blur_false_for_empty_registry() {
        let v: serde_json::Value = serde_json::from_str(&render_json(&[])).unwrap();
        assert_eq!(v["compositor_blur"], false);
        assert_eq!(v["globals"], serde_json::json!([]));
    }

    #[test]
    fn output_is_single_line_with_blur_field() {
        let out = render_json(&names(&["wl_compositor"]));
        assert!(!out.contains('\n'));
        assert!(out.contains("\"compositor_blur\""));
    }
}
