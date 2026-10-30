#![forbid(unsafe_code)]

//! 虚拟指针注入：通过 `zwlr_virtual_pointer_manager_v1` 向当前 Wayland
//! 合成器注入绝对移动/点击/滚动。只影响它连接的那个合成器——verify.sh
//! 的隔离 sway——不会碰到用户会话里真实的输入设备。
//!
//! 用法：
//!   nosd-helpers vinput move <x> <y> [W H]
//!   nosd-helpers vinput click|rclick|mclick <x> <y> [W H]
//!   nosd-helpers vinput jclick <x> <y> <dx> <dy> [W H]  // 按下-抖动-抬起，探拖拽阈值
//!   nosd-helpers vinput drag <x1> <y1> <x2> <y2> [W H]  // 按住拖动
//!   nosd-helpers vinput scroll <x> <y> <dy> [W H]
//!   nosd-helpers vinput hold                             // 常驻，直到被 kill
//!
//! hold 只创建一个虚拟指针然后一直挂着。合成器没有真实输入设备时（verify 的
//! 无头 sway），seat 的指针能力完全来自这些虚拟指针：每次操作的进程一退出，
//! seat 就失去指针能力，所有客户端随之释放 wl_pointer；下一次操作新建设备时，
//! 客户端要重新 get_pointer，正忙着渲染的 shell 会晚于按下才拿到指针，于是
//! 只收到松开。会话开始时先起一个 hold，seat 就一直有指针，和真实桌面一样。
//!
//! W/H 为绝对坐标的映射区间，默认 1920x1080（verify 的无头输出），
//! 永远排在各操作自己的坐标参数之后。
//!
//! VINPUT_HOLD_MS: 进程退出前先 sleep 这么多毫秒——虚拟指针随进程销毁，
//! 销毁时合成器会给悬停面发 leave，hover 状态在截图前就复位了。
//! 需要 hover 可见的场景在 move 上加这个环境变量，并在截图前并行睡同样的
//! 时长由 shot 侧控制。
//!
//! VINPUT_PRESS_MS: click 系列按下与抬起之间保持这么多毫秒（默认 50）。每次
//! 点击都先单独送出移动、等 50 ms 再按下，并在按下后立即 flush：sway 会丢掉
//! 与"移入新表面"同批到达的按下。调大它可以拍按压态的动效（verify.sh 的
//! motion-press 场景）。

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
    // v2 adds axis_discrete — binding v1 and sending it anyway is a protocol
    // error: the compositor drops the rest of the scroll sequence (the
    // "wheel never arrives" symptom) or disconnects the virtual pointer.
    let mgr: ZwlrVirtualPointerManagerV1 = globals
        .bind(&queue.handle(), 1..=2, ())
        .map_err(|_| {
            "vinput: zwlr_virtual_pointer_manager_v1 not available in this compositor".to_string()
        })?;
    let vp: ZwlrVirtualPointerV1 = mgr.create_virtual_pointer(Some(&seat), &queue.handle(), ());
    queue
        .roundtrip(&mut state)
        .map_err(|e| format!("vinput: roundtrip failed: {e}"))?;

    // Optional [W H] extent override comes AFTER each op's own coords —
    // move/click take it at p[2..4], jclick/drag at p[4..6], scroll at p[3..5].
    let extent_at = |i: usize| -> (u32, u32) {
        let w = arg_f32(p, i).unwrap_or(1920.0).max(1.0);
        let h = arg_f32(p, i + 1).unwrap_or(1080.0).max(1.0);
        (w as u32, h as u32)
    };
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

    let move_to = |vp: &ZwlrVirtualPointerV1, x: f32, y: f32, ew: u32, eh: u32, t: u32| {
        vp.motion_absolute(t, x as u32, y as u32, ew, eh);
        vp.frame();
    };
    match op {
        "hold" => loop {
            // Keep the device (and the connection) alive; events are never
            // sent, so there is nothing to dispatch.
            sleep(Duration::from_secs(3600));
        },
        "move" => {
            let (ew, eh) = extent_at(2);
            move_to(&vp, arg_f32(p, 0)?, arg_f32(p, 1)?, ew, eh, tick());
            flush(&mut queue);
        }
        "click" | "rclick" | "mclick" => {
            let btn = match op {
                "rclick" => BTN_RIGHT,
                "mclick" => BTN_MIDDLE,
                _ => BTN_LEFT,
            };
            let (ew, eh) = extent_at(2);
            let (x, y) = (arg_f32(p, 0)?, arg_f32(p, 1)?);
            let hold = std::env::var("VINPUT_PRESS_MS").ok().and_then(|v| v.parse::<u64>().ok()).unwrap_or(50);
            // Deliver the motion first and give the compositor a beat before
            // the press, so the press goes to the surface the motion entered.
            // A client sees enter and then only the release when it has no
            // wl_pointer at press time; that is a seat without a resident
            // pointer (see hold above), which this delay cannot cover.
            move_to(&vp, x, y, ew, eh, tick());
            flush(&mut queue);
            sleep(Duration::from_millis(50));
            t += 50;
            vp.button(t, btn, wl_pointer::ButtonState::Pressed);
            vp.frame();
            flush(&mut queue);
            sleep(Duration::from_millis(hold));
            t += hold as u32;
            vp.button(t, btn, wl_pointer::ButtonState::Released);
            vp.frame();
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
            let (ew, eh) = extent_at(4);
            vp.motion_absolute(t, x as u32, y as u32, ew, eh);
            vp.frame();
            t += 30;
            vp.button(t, BTN_LEFT, wl_pointer::ButtonState::Pressed);
            vp.frame();
            sleep(Duration::from_millis(60));
            t += 60;
            vp.motion_absolute(t, (x + dx) as u32, (y + dy) as u32, ew, eh);
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
            let (ew, eh) = extent_at(4);
            vp.motion_absolute(t, x1 as u32, y1 as u32, ew, eh);
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
                    ew,
                    eh,
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
            let (ew, eh) = extent_at(3);
            vp.motion_absolute(t, arg_f32(p, 0)? as u32, arg_f32(p, 1)? as u32, ew, eh);
            vp.frame();
            t += 30;
            // Emit a wheel-source axis pair like a real mouse: compositors
            // that ignore bare continuous axis events still route these, and
            // Qt turns the discrete component into angleDelta.
            vp.axis_source(wl_pointer::AxisSource::Wheel);
            vp.axis_discrete(t, wl_pointer::Axis::VerticalScroll, dy as f64, (dy / 120.0) as i32);
            vp.axis(t, wl_pointer::Axis::VerticalScroll, dy as f64);
            vp.frame();
            flush(&mut queue);
        }
        _ => return Err(format!("vinput: unknown op '{op}'")),
    }

    // Let the compositor deliver the queued events before the pointer dies.
    sleep(Duration::from_millis(150));
    // VINPUT_HOLD_MS keeps the virtual pointer alive past delivery — the
    // pointer is destroyed on exit, which sends a leave event that resets
    // hover state before a screenshot can capture it.
    if let Ok(ms) = std::env::var("VINPUT_HOLD_MS").map_err(|_| ()).and_then(|v| v.parse::<u64>().map_err(|_| ())) {
        sleep(Duration::from_millis(ms));
    }
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
