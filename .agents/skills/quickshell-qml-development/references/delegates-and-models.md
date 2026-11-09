# Delegates, models, and provider results

## 1. Required properties live in exactly one place

A delegate component declares them:

```qml
// MyCell.qml
Item {
  required property var modelData
  required property int index
  property var gridView: GridView.view   // may be null during early evaluation
}
```

The usage binds the rest, and **never redeclares**:

```qml
delegate: MyCell {
  width: resultsGrid.effectiveCellWidth
  iconSize: 32
}
```

Redeclaring a `required property` inline (because the component also declares it)
produces, for every item:

```
WARN ... Cannot create delegate
WARN ... Required property modelData was not initialized
```

The log names the **view's line of the `delegate:` block**, not the component
file, which sends you to the wrong file — check the component's own declarations
nfirst.

## 2. Grid/ListView handle access

- `GridView.view` inside a grid delegate (not `ListView.view`), and it is `null`
  during early evaluation — null-guard every `root.gridView.x` access.
- `NListView`-style wrappers usually expose `spacing` as an alias; `NGridView`
  historically had none. When adding a missing property (e.g. `spacing`), derive
  `effectiveCellWidth/cellHeight = cell - spacing` so existing consumers that use
  the default `0` are unaffected.

## 3. Model shape and split between list vs grid

A plain JS array works fine with `GridView`/`ListView`. When one model feeds two
different presentations (grid while browsing, list while searching), make the
split explicit with one named predicate instead of duplicating filters:

```qml
readonly property bool browsing: model.searchText.trim() === "" && !model.activeProvider
readonly property var listResults: root.browsing ? [] : model.results
readonly property var appResults: root.browsing ? model.results : []
```

Selection belongs to the model (`selectedIndex`), and the view binds
`currentIndex: model.selectedIndex`; the delegate highlights via
`index === gridView.currentIndex`, guarding for null.

## 4. Provider result objects

- Each result carries `provider` pointing at the producing provider object, plus
  an `onActivate` callback. Views should not special-case providers by name —
  compare object identity (`r.provider === appsProvider`).
- Providers need a handle on their owner to report back:
  `property var launcher: null`, assigned at registration time. **Pass
  registration ids as function arguments** (`registerProvider(p, "apps")`),
  never by writing `p.providerId = "apps"` — QML rejects writes to undeclared
  properties as a warning, silently dropping the value.
- Deferred/reloading data (`loadApplications()`, clipboard scans, XDG scans) is
  invisible to a view that already rendered. End every such load with a callback
  into the owner (`launcher.updateResults()`), or the empty snapshot sticks even
  though the log says the data arrived.

## 5. Binding loops

A `readonly property var { ... }` binding that writes a property it reads
(even a counter for logging) is a binding loop; QML disables the binding and
warns once. Log from functions and handlers, never from a property binding.

## 6. One flat descriptor array for a grouped/sectioned list

When a view needs section headers, collapsible groups and items (a history
list, an inbox), build **one** flat array of row descriptors and give it to a
single `ListView`/`Repeater`. Do not nest a view per section, and do not keep
a parallel "visible indices" list — the keyboard's row space and the view's
row space must be the same array or `↑/↓` drifts out of sync with what is on
screen.

```qml
readonly property var descriptors: { /* rows: {kind: "header"|"section"|"group"|"notif", ...} */ }
readonly property var visibleRows: { /* filter to the rows the keyboard walks */ }
```

- **A row carries the source index, never the object.** The delegate reads the
  live entry (`service.model.get(row.modelIndex)`), so an async
  `setProperty` on that model (an image cache finishing, a field updating)
  still reaches the delegate. Holding `model.get(i)` in the row itself is the
  copy-trap the project's modelData rules already ban.
- **Group keys must be scoped to their section.** Two sections can contain the
  same group key (`today|Firefox` vs `yesterday|Firefox`); an unscoped key
  expands or clears both at once. Encode the bucket into the key.
- **Anything computed from a total is wrong on the first row.** Group size is
  only final after the whole model is walked, so a one-pass builder that reads
  `rows[groupStart].count` while pushing hands row 1 a size of 1 forever — the
  collapsed/expanded branch then never fires and the group renders as a single
  item. Build rows in pass one, then fill sizes and head/tail flags in pass
  two.
- A row's `height` must not read its own children's `height`/`visible`: that
  is a binding loop in disguise. Recompute the same predicates on the row
  itself (see trap 14b for the sibling case).
- Rows with no source index (header/section) must default it
  (`modelData.modelIndex || 0`) — an `int` property assigned `undefined` logs
  `Unable to assign [undefined] to int` on every row.


## 7. Re-entrant calls inside an incubation window crash the engine (SIGSEGV)

Crash signature: `QQmlIncubatorPrivate::incubate` on the stack, under
`QMetaObject::propertyCount` / `QV4::Object::insertMember`, usually reported as
"quickshell died with no QML error". The trigger is not a bad binding but a
*re-entrant* one: while a delegate is incubating (or a view is resetting its
model), a synchronous callback / service call / model write re-enters the V4
engine. Four sites hit this in this repo, each with the same shape and its own
narrow fix:

| Site | Re-entrancy | Fix |
|------|-------------|-----|
| NotificationService inserts synchronously while a `Repeater` incubates | insert during incubation | `Qt.callLater` the insert |
| `BarContentWindow` destroys and recreates its widget `Loader` on hide | teardown/re-incubate on every hide | keep it resident, do not unload |
| `launcher` delegate calls `provider.prepareItem` from `Component.onCompleted` | callback writes the model back mid-incubation | `callLater` the write |
| `dock` reassigns `dockApps` wholesale inside a toplevel/SNI signal burst | full reassign per signal, two resets per keystroke in `_results` | `callLater` to merge into one event-loop turn **plus** per-element identity compare, skip the assignment when nothing changed |

Defensive rules, cheapest first:

1. Never call a service that emits from `Component.onCompleted` /
   `Component.onDestruction` of a delegate.
2. Assign a model array once. `clear()` then append is two resets, i.e. two
   incubation windows — build the new array and assign it in one write.
3. Views that toggle visibility frequently stay resident; destroying content on
   hide costs a re-incubation every time.
4. Any signal-driven model rebuild goes through `callLater`, and the rebuild
   result is compared by identity against the current model: delegate bindings
   already reflect `title` / `urgent` changes, so re-assigning an identical
   model buys nothing but a teardown/re-incubate window.

Related amplifier, same failure family: a per-file `valuesChanged` notification
during startup scan plus `Qt.createQmlObject` inside a delegate turns an O(n)
scan into O(n²) compilation (one core pinned to ~94% until the scan ends).
Merge the notifications behind a ~400 ms debounce timer and throttle
`updateResults` with `Qt.callLater`. Diagnostic: `eu-stack` on the qs main
thread shows `setModel → incubate → createQmlObject → loadWithStaticData`
recursing — and reproduce on a pure `HEAD` baseline first, because the
symptom looks exactly like "my last commit broke it".

Also: an animation formula driven by a phase parameter must be verified to
read *exactly* zero at rest (`8*sin(phase*…)` returned 8° at `phase=0`); gate
it (`anim.running ? formula : 0`) or prove the rest state.

Source: agenote 20261008-180537, 20261007-131552.
