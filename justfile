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
build:
    guix build -f nosdshell.scm

#   Stops the shepherd `nosdshell` service and any previous manual instance,
#   then starts <store>/bin/nosdshell detached (log: /tmp/nosdshell-manual.log).
#   `just restore` hands back to the packaged generation.
# Build the working tree and run it in place of the packaged shell.
run:
    #!/usr/bin/env bash
    set -euo pipefail
    store=$(guix build -f nosdshell.scm | tail -n1)
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
