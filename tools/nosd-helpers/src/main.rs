#![forbid(unsafe_code)]

//! nosd-helpers: small nosDshell helper tools in one binary.
//! Subcommands mirror the Scripts/python helpers; QML callers get a
//! fallback chain (rust binary -> python script) so rollout is gradual.

mod apply;
mod bluetooth;
mod eds;
mod gtk_refresh;
mod ical;
mod kde_apply;
mod khal_events;
mod vscode_themes;

use std::env;
use std::process::ExitCode;

fn usage() -> ! {
    eprintln!("Usage: nosd-helpers <vscode-themes|kde-apply-scheme|gtk-refresh|khal-events|bluetooth-pair|eds-check|eds-calendars|eds-events|apply> [ARGS...]");
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
        _ => usage(),
    };
    ExitCode::from(code as u8)
}
