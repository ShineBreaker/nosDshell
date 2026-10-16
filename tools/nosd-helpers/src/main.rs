#![forbid(unsafe_code)]

//! nosd-helpers: small nosDshell helper tools in one binary.
//! Subcommands were ported from the Scripts/python helpers (removed once
//! the Rust ports reached parity); QML callers invoke the binary directly.

mod apply;
mod bluetooth;
mod eds;
mod gtk_refresh;
mod ical;
mod kde_apply;
mod khal_events;
mod portal;
mod vinput;
mod vscode_themes;
mod wl_probe;
use std::env;
use std::process::ExitCode;

fn usage() -> ! {
    eprintln!("Usage: nosd-helpers <vscode-themes|kde-apply-scheme|gtk-refresh|khal-events|bluetooth-pair|eds-check|eds-calendars|eds-events|apply|wl-probe|vinput|portal> [ARGS...]");
    std::process::exit(2);
}

fn main() -> ExitCode {
    let mut args = env::args().skip(1);
    let sub = args.next().unwrap_or_else(|| usage());
    let rest: Vec<String> = args.collect();
    let code = match sub.as_str() {
        "vscode-themes" => vscode_themes::run(&rest),
        "kde-apply-scheme" => kde_apply::run(&rest),
        "gtk-refresh" => gtk_refresh::run(&rest),
        "khal-events" => khal_events::run(&rest),
        "bluetooth-pair" => bluetooth::run(&rest),
        "eds-check" => eds::run_check(&rest),
        "eds-calendars" => eds::run_calendars(&rest),
        "eds-events" => eds::run_events(&rest),
        "apply" => apply::run(&rest),
        "wl-probe" => wl_probe::run(&rest),
        "vinput" => vinput::run(&rest),
        "portal" => portal::run(&rest),
        _ => usage(),
    };
    ExitCode::from(code as u8)
}
