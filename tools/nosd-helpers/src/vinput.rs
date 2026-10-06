#![forbid(unsafe_code)]

//! 虚拟指针注入：通过 `zwlr_virtual_pointer_manager_v1` 向当前 Wayland
//! 合成器注入绝对移动/点击/滚动。只影响它连接的那个合成器——verify.sh
//! 的隔离 sway——不会碰到用户会话里真实的输入设备。
//!
//! 用法：
//!   nosd-helpers vinput move <x> <y> [W H]
//!   nosd-helpers vinput click|rclick|mclick <x> <y> [W H]
//!   nosd-helpers vinput jclick <x> <y> <dx> <dy>   // 按下-抖动-抬起，探拖拽阈值
//!   nosd-helpers vinput drag <x1> <y1> <x2> <y2>   // 按住拖动
//!   nosd-helpers vinput scroll <x> <y> <dy>
//!
//! W/H 为绝对坐标的映射区间，默认 1920x1080（verify 的无头输出）。

use std::thread::sleep;
use std::time::Duration;
use wayland_client::globals::{GlobalListContents, registry_queue_init};
use wayland_client::protocol::{wl_pointer, wl_registry, wl_seat};
use wayland_client::{Connection, Dispatch, Proxy, QueueHandle};
use wayland_protocols_wlr::virtual_pointer::v1::client::zwlr_virtual_pointer_manager_v1::ZwlrVirtualPointerManagerV1;
use wayland_protocols_wlr::virtual_pointer::v1::client::zwlr_virtual_pointer_v1::ZwlrVirtualPointerV1;

const BTN_LEFT: u32 = 0x110;
const BTN_RIGHT: u32 = 0x111;
const BTN_MIDDLE: u32 = 0x112;

struct State;

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for State {
    fn event(
        _s: &mut Self,
        _p: &wl_registry::WlRegistry,
        _e: wl_registry::Event,
        _d: &GlobalListContents,
        _c: &Connection,
        _q: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<wl_seat::WlSeat, ()> for State {
    fn event(
        _s: &mut Self,
        _p: &wl_seat::WlSeat,
        _e: wl_seat::Event,
        _d: &(),
        _c: &Connection,
        _q: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZwlrVirtualPointerManagerV1, ()> for State {
    fn event(
        _s: &mut Self,
        _p: &ZwlrVirtualPointerManagerV1,
        _e: <ZwlrVirtualPointerManagerV1 as Proxy>::Event,
        _d: &(),
        _c: &Connection,
        _q: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZwlrVirtualPointerV1, ()> for State {
    fn event(
        _s: &mut Self,
        _p: &ZwlrVirtualPointerV1,
        _e: <ZwlrVirtualPointerV1 as Proxy>::Event,
        _d: &(),
        _c: &Connection,
        _q: &QueueHandle<Self>,
    ) {
    }
}

fn arg_f32(args: &[String], i: usize) -> Result<f32, String> {
    args.get(i)
        .and_then(|s| s.parse::<f32>().ok())
        .ok_or_else(|| format!("vinput: argument {} missing or not a number", i + 1))
}

fn run_op(args: &[String]) -> Result<(), String> {
    let op = args.first().ok_or("vinput: missing op")?.as_str();
    let p = &args[1.min(args.len())..]; // coords start after the op

    let conn = Connection::connect_to_env()
        .map_err(|e| format!("vinput: connect to Wayland failed: {e}"))?;
    let (globals, mut queue) = registry_queue_init::<State>(&conn)
        .map_err(|e| format!("vinput: registry init failed: {e}"))?;
    let mut state = State;
    queue
        .roundtrip(&mut state)
        .map_err(|e| format!("vinput: roundtrip failed: {e}"))?;

    let seat: wl_seat::WlSeat = globals
        .bind(&queue.handle(), 1..=7, ())
        .map_err(|_| "vinput: no wl_seat global".to_string())?;
    let mgr: ZwlrVirtualPointerManagerV1 = globals
        .bind(&queue.handle(), 1..=1, ())
        .map_err(|_| {
            "vinput: zwlr_virtual_pointer_manager_v1 not available in this compositor".to_string()
        })?;
    let vp: ZwlrVirtualPointerV1 = mgr.create_virtual_pointer(Some(&seat), &queue.handle(), ());
    queue
        .roundtrip(&mut state)
        .map_err(|e| format!("vinput: roundtrip failed: {e}"))?;

    let ew = arg_f32(p, 2).unwrap_or(1920.0);
    let eh = arg_f32(p, 3).unwrap_or(1080.0);
    let mut t: u32 = 0;
    let mut tick = || {
        t += 10;
        t
    };
    let mut flush = |queue: &mut wayland_client::EventQueue<State>| {
        queue
            .roundtrip(&mut state)
            .map_err(|e| format!("vinput: roundtrip failed: {e}"))
            .unwrap();
    };

    let move_to = |vp: &ZwlrVirtualPointerV1, x: f32, y: f32, t: u32| {
        vp.motion_absolute(t, x as u32, y as u32, ew as u32, eh as u32);
        vp.frame();
    };
    let click_at = |vp: &ZwlrVirtualPointerV1, x: f32, y: f32, btn: u32, t: &mut u32| {
        vp.motion_absolute(*t, x as u32, y as u32, ew as u32, eh as u32);
        vp.frame();
        *t += 30;
        vp.button(*t, btn, wl_pointer::ButtonState::Pressed);
        vp.frame();
        sleep(Duration::from_millis(50));
        *t += 50;
        vp.button(*t, btn, wl_pointer::ButtonState::Released);
        vp.frame();
    };

    match op {
        "move" => {
            move_to(&vp, arg_f32(p, 0)?, arg_f32(p, 1)?, tick());
            flush(&mut queue);
        }
        "click" | "rclick" | "mclick" => {
            let btn = match op {
                "rclick" => BTN_RIGHT,
                "mclick" => BTN_MIDDLE,
                _ => BTN_LEFT,
            };
            click_at(&vp, arg_f32(p, 0)?, arg_f32(p, 1)?, btn, &mut t);
            flush(&mut queue);
        }
        "jclick" => {
            // press, jitter by (dx,dy) while held, release — simulates the
            // 1-2px shake of a real mouse click that flickables read as a drag.
            let (x, y, dx, dy) = (
                arg_f32(p, 0)?,
                arg_f32(p, 1)?,
                arg_f32(p, 2)?,
                arg_f32(p, 3)?,
            );
            vp.motion_absolute(t, x as u32, y as u32, ew as u32, eh as u32);
            vp.frame();
            t += 30;
            vp.button(t, BTN_LEFT, wl_pointer::ButtonState::Pressed);
            vp.frame();
            sleep(Duration::from_millis(60));
            t += 60;
            vp.motion_absolute(t, (x + dx) as u32, (y + dy) as u32, ew as u32, eh as u32);
            vp.frame();
            sleep(Duration::from_millis(60));
            t += 60;
            vp.button(t, BTN_LEFT, wl_pointer::ButtonState::Released);
            vp.frame();
            flush(&mut queue);
        }
        "drag" => {
            let (x1, y1, x2, y2) = (
                arg_f32(p, 0)?,
                arg_f32(p, 1)?,
                arg_f32(p, 2)?,
                arg_f32(p, 3)?,
            );
            vp.motion_absolute(t, x1 as u32, y1 as u32, ew as u32, eh as u32);
            vp.frame();
            t += 30;
            vp.button(t, BTN_LEFT, wl_pointer::ButtonState::Pressed);
            vp.frame();
            sleep(Duration::from_millis(80));
            for i in 1..=8 {
                t += 20;
                let f = i as f32 / 8.0;
                vp.motion_absolute(
                    t,
                    (x1 + (x2 - x1) * f) as u32,
                    (y1 + (y2 - y1) * f) as u32,
                    ew as u32,
                    eh as u32,
                );
                vp.frame();
                sleep(Duration::from_millis(20));
            }
            t += 40;
            vp.button(t, BTN_LEFT, wl_pointer::ButtonState::Released);
            vp.frame();
            flush(&mut queue);
        }
        "scroll" => {
            let dy = arg_f32(p, 2)?;
            vp.motion_absolute(t, arg_f32(p, 0)? as u32, arg_f32(p, 1)? as u32, ew as u32, eh as u32);
            vp.frame();
            t += 30;
            vp.axis(t, wl_pointer::Axis::VerticalScroll, dy as f64);
            vp.frame();
            flush(&mut queue);
        }
        _ => return Err(format!("vinput: unknown op '{op}'")),
    }

    // Let the compositor deliver the queued events before the pointer dies.
    sleep(Duration::from_millis(150));
    queue
        .roundtrip(&mut state)
        .map_err(|e| format!("vinput: final roundtrip failed: {e}"))?;
    Ok(())
}

pub fn run(args: &[String]) -> i32 {
    match run_op(args) {
        Ok(()) => 0,
        Err(msg) => {
            eprintln!("{msg}");
            1
        }
    }
}
