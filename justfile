# nosDshell task runner — `just` lists these recipes.
# High-frequency dev/release operations wrapped around Scripts/ + guix.

set positional-arguments

# List recipes (default).
default:
    @just --list --unsorted

# ---- code quality -----------------------------------------------------------

# Lint changed files (run after every edit).
lint:
    Scripts/dev/lint.sh --changed

# Lint the whole repository.
lint-all:
    Scripts/dev/lint.sh

# Format QML files: just fmt Widgets/NComboBox.qml ...
fmt +files:
    Scripts/dev/qmlfmt.sh {{files}}

# Rebuild the settings search index after adding/renaming settings.
search-index:
    python3 Scripts/test/build-settings-search-index.py

# ---- verify / bench ---------------------------------------------------------

# Isolated verify run: just verify myrun --scenes settings-combo
verify run +args:
    Scripts/test/verify.sh {{run}} {{args}}

# One perf round — startup_ms + panel_toggle_ms (drop the cold first run).
bench:
    Scripts/test/bench.sh

# ---- rust tools --------------------------------------------------------------

# Release-build all three Rust helpers (verify.sh prefers target/release).
tools:
    cargo build --release --manifest-path tools/nosd-helpers/Cargo.toml
    cargo build --release --manifest-path tools/nosd-theme/Cargo.toml
    cargo build --release --manifest-path tools/nosd-blur/Cargo.toml

# ---- run ---------------------------------------------------------------------

# guix-build the working tree package, print the store path.
# Uses the same channel lock as `just run` so the binary matches what
# the packaged service runs (Qt 6.12, not the moving guix channel's
# Qt 6.9.2).
build:
    #!/usr/bin/env bash
    set -euo pipefail
    channel_lock="${GUIX_CHANNEL_LOCK:-$HOME/.config/guix/trusted-channels.scm}"
    if [ -f "$channel_lock" ]; then
      guix time-machine -C "$channel_lock" -- build -f nosdshell.scm
    else
      guix build -f nosdshell.scm
    fi

#   Stops the shepherd `nosdshell` service and any previous manual instance,
#   then starts <store>/bin/nosdshell detached (log: /tmp/nosdshell-manual.log).
#   `just restore` hands back to the packaged generation.
# Build the working tree and run it in place of the packaged shell.
# Builds inside `guix time-machine` pinned to channel.lock so the
# resulting nosdshell sees the same Qt/quickshell revisions as the
# packaged shepherd service (Qt 6.12). Without the pin, `guix build`
# resolves `(inherit quickshell)` against the user's current guix
# channel, which carries Qt 6.9.2 — that Qt release has a known
# QQmlDelegateModel::_q_itemsChanged UAF that makes the shell SIGSEGV
# during startup when WallpaperService fills its model while delegates
# are being instantiated.
run:
    #!/usr/bin/env bash
    set -euo pipefail
    channel_lock="${GUIX_CHANNEL_LOCK:-$HOME/.config/guix/trusted-channels.scm}"
    if [ -f "$channel_lock" ]; then
      store=$(guix time-machine -C "$channel_lock" -- build -f nosdshell.scm | tail -n1)
    else
      store=$(guix build -f nosdshell.scm | tail -n1)
    fi
    echo "built: $store"
    herd stop nosdshell 2>/dev/null || true
    # The real process is `quickshell --config <store>/etc/xdg/...` — clear a
    # previous manual instance too, not just the shepherd one.
    pkill -f 'quickshell --config /gnu/store/.*nosdshell' 2>/dev/null || true
    sleep 0.5
    setsid "$store/bin/nosdshell" </dev/null >>/tmp/nosdshell-manual.log 2>&1 &
    echo "running $store/bin/nosdshell (log: /tmp/nosdshell-manual.log)"
    echo "restore the packaged service with: just restore"

# Stop a manual shell and restart the packaged shepherd service.
restore:
    pkill -f 'quickshell --config /gnu/store/.*nosdshell' 2>/dev/null || true
    herd start nosdshell

# ---- release -----------------------------------------------------------------

#   Empty [Unreleased] → scaffolds commit links; fill the intro, re-run.
# Cut a release: just release 1.1.2 [--no-push] [--skip-verify]
release ver +args:
    Scripts/dev/release.sh {{ver}} {{args}}
