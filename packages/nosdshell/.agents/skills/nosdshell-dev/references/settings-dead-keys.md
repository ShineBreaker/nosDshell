# Auditing "dead" settings keys

Deleting a setting because `grep data.<key>` finds no reader has already
mis-fired here: live keys were classified dead and their UI was removed. The
audit must separate four buckets, in this order — each bucket one level harder
to prove than the last.

## 1. Truly dead

Zero non-settings-UI reads in the whole tree. Examples: `controlCenter.position`
(`ControlCenterPanel.qml:100` even self-documents as inert),
`dock.floatingRatio`, `dock.animationSpeed`. Verified two ways: `grep` for
`data.<key>` and a pixel diff with the key toggled (0.06% / 0.01% changed —
equal to screenshot noise).

## 2. Indirectly live — rerouted through a singleton

A reader exists but goes through a helper, so grepping `data.<key>` misses it.
`bar.barType` is only read by `getEffectiveBarType()` (`Settings.qml:1098-1102`),
and that function returns `simple` unconditionally while
`dock.mode === "efficient"` — so `framed` is inert *in that mode only*, not
dead. Always follow the accessor, then its branches.

## 3. Bypass-live — runtime-dead but migration-live

Nothing reads it at runtime, yet a migration writes its value into a key that
does take effect. `dock.displayMode` is translated by `Migration70` into
`dock.hideMode` (`auto_hide` → `keep-hidden`), so writing it still changes the
UI. Mark such keys `dead-but-migratable` instead of deleting them; deleting the
migration strand is a separate, deliberate change.

## 4. Frontend-gated dead — reads exist but the consumer never opens

The nastiest case: real reads, plausible key names, and the reading component
is never instantiated because nothing opens it. Seven launcher settings
(`position`, `viewMode`, `density`, `showCategories`, `iconMode`,
`showIconBackground`, `ignoreMouseInput`) were consumed only by
`LauncherCore` / `SmartPanel`, while `PanelService.toggleLauncher` routes on
`appLauncher.overviewLayer` (default `false` → DDE's `LauncherState`
fullscreen/mini view). `Launcher.qml` had no open path at all. Test: after
finding the consumer, **follow the open chain** — who instantiates it, who
calls `setVisible`/`open` — and stop trusting "there is a reference".

## Traps that survive the four buckets

- `dock.deadOpacity` has a reader (`DockContent.qml:647`);
  `dock.sitOnFrame` / `dock.backgroundOpacity` / `dock.size` are read only by
  `StaticDockPanel`, which does not render in fashion mode. Judging by fashion
  mode alone would call them dead; the static path is live.
- `dock.animationSpeed` and `general.animationSpeed` collide by name across
  sections (`Style.qml:87-91,350`). The settings slider writes the dead one.
- `bar.density` has two semantic paths: `Style` resolves per-screen overrides
  through `getBarDensityForScreen`, `Tray.qml:62` reads the global directly.
  Changing one does not move the other.

## Related authority

Runtime defaults live in the `Commons/Settings.qml` schema (each `property`'s
initializer), **not** in `Assets/settings-default.json` — the JSON is the
first-boot / "restore defaults" value. An isolated run that set
`viewMode: "grid"` in the JSON still wrote `"list"` from the schema.

Source: agenote 20261006-220122, 20261011-025351.
