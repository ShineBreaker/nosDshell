import QtQuick

// Explicit finite-state machine for logic-layer lifecycles (panel open/close,
// reveal/hold/hide, countdowns, async request phases). Replaces the
// bool+Timer encoding the shell used to grow per call site: N flags made
// 2^N combinations — most of them impossible, none of them validated — and
// every "watchdog" timer was a symptom of a transition nobody declared.
//
// Contract:
//   * `state` is the single source of truth; consumers project it back into
//     the legacy flag surface (`readonly property bool isOpen: fsm.is("open")`)
//     so existing bindings keep working while writers go through transition().
//   * `transitions` declares the legal edges. transition() to an undeclared
//     edge is rejected and logged — illegal states become visible instead of
//     reachable.
//   * `timeouts` declares the timers a state used to carry: each spec arms on
//     state entry and fires transition() on expiry, so a state timeout can
//     never outlive its state or leak into the next one.
//   * Every machine registers itself into StateRegistry under `name` — the
//     IPC `state all` snapshot then shows live phase data for every
//     converted lifecycle (agent/debug surface).
//
// Usage:
//   NStateMachine {
//     id: lifecycle
//     name: "panel:sessionMenu@" + (root.screen?.name || "?")
//     states: ["closed", "open", "closing"]
//     state: "closed"
//     transitions: ({
//       "closed":  ["open"],
//       "open":    ["closing"],
//       "closing": ["open", "closed"]
//     })
//     timeouts: ({
//       "closing": [{"after": () => Style.motionEnter + 30, "to": "closed"}]
//     })
//     onEntered: state => { /* entry effects */ }
//   }
//
// `after` is ms or a zero-arg function evaluated on entry — the duration is
// re-read per arm so Style.motion* changes apply at the next entry. A spec
// resolving to <= 0 simply never arms (watchdogs skip zero-duration paths,
// matching the old `if (duration > 0)` guards).
QtObject {
  id: machine

  // Ordered list of legal states; required. `state` defaults to the first.
  required property var states

  // The one live state. Write through transition() — direct assignment
  // skips guards, timeouts and logging (kept writable only for tests).
  property string state: ""

  // State before the current one; "" before the first transition.
  readonly property string previous: _previous
  // Wall time (ms) when the current state was entered — stuck-state forensics.
  readonly property double enteredAt: _enteredAt

  // Legal edges: {"from": ["to", ...]}. Empty map = all edges legal.
  property var transitions: ({})

  // Per-state timed transitions: {"state": [spec, ...]} with spec
  // {"after": ms | function, "to": state, "warn": optional Logger.w text}.
  property var timeouts: ({})

  // Registry/log tag — unique per live instance (embed the screen name for
  // per-screen machines). Empty = unregistered. Late-bound names (a screen
  // assigned after construction) re-register under the new key.
  property string name: ""
  property string _registeredName: ""

  onNameChanged: {
    if (name === _registeredName)
      return;
    if (_registeredName !== "")
      StateRegistry.unregister(_registeredName);
    _registeredName = "";
    if (name !== "" && state !== "") {
      _registeredName = _claimName();
      StateRegistry.register(_registeredName, state, _enteredAt);
    }
  }

  // Claim a registry key: several anonymous instances can share one `name`
  // (panels without objectName all become "panel:smart@screen") — each gets
  // its own row under name, name#2, name#3, … instead of clobbering it.
  function _claimName() {
    if (!StateRegistry.has(name))
      return name;
    var i = 2;
    while (StateRegistry.has(name + "#" + i))
      ++i;
    return name + "#" + i;
  }

  signal entered(string state)
  signal exited(string state)
  // A transition() request was refused (unknown target or illegal edge).
  signal rejected(string from, string to)

  property string _previous: ""
  property double _enteredAt: 0
  property var _armedTimers: []

  // NO return-type annotation here: annotated QML functions drop the
  // `arguments` object, so is("open", "closing") would silently see zero
  // args and always return false.
  function is() {
    for (var i = 0; i < arguments.length; ++i) {
      if (state === arguments[i])
        return true;
    }
    return false;
  }

  // Request an edge. `force` bypasses the edge table and allows a self-edge
  // (a real re-entry: exited+entered fire, timeouts re-arm) — that is the
  // shape of "re-start the thing already running" and of unconditional
  // resets like closeImmediately().
  function transition(to, force): bool {
    if (states.indexOf(to) === -1) {
      _reject(to, "unknown state");
      return false;
    }
    if (to === state && !force)
      return false;
    if (!force && Object.keys(transitions).length > 0) {
      const allowed = transitions[state] || [];
      if (allowed.indexOf(to) === -1) {
        _reject(to, "illegal edge");
        return false;
      }
    }
    Logger.d("StateMachine", machine.name + ":", state, "->", to);
    exited(state);
    _previous = state;
    state = to;
    _enteredAt = Date.now();
    if (_registeredName !== "")
      StateRegistry.update(_registeredName, state, _previous, _enteredAt);
    _rearm();
    entered(state);
    return true;
  }

  function _reject(to, why) {
    Logger.w("StateMachine", machine.name + ": rejected", state, "->", to, "(" + why + ")");
    rejected(state, to);
  }

  // Re-evaluate which timeout specs arm under the current state.
  function _rearm() {
    for (var i = 0; i < _armedTimers.length; ++i) {
      const entry = _armedTimers[i];
      if (state !== entry.armedIn) {
        entry.timer.stop();
        continue;
      }
      const spec = entry.spec;
      const ms = (typeof spec.after === "function") ? spec.after() : spec.after;
      if (ms > 0) {
        entry.timer.interval = ms;
        entry.timer.restart();
      } else {
        entry.timer.stop();
      }
    }
  }

  function _onTimeout(spec) {
    const warn = (typeof spec.warn === "function") ? spec.warn() : spec.warn;
    if (warn && warn !== "")
      Logger.w("StateMachine", machine.name + ":", warn);
    transition(spec.to);
  }

  // Component can't sit in a QtObject's default property — declare it.
  property Component _timerProto: Component {
    Timer {
      repeat: false
    }
  }

  Component.onCompleted: {
    if (states.indexOf(state) === -1) {
      if (state !== "")
        Logger.w("StateMachine", machine.name + ": initial state", state, "not in states — using", states[0]);
      state = states[0];
    }
    _enteredAt = Date.now();

    // Flatten the timeouts map into armed timers; validate spec states the
    // same way the edge table is validated, so a typo fails loudly once at
    // build time instead of silently never firing.
    const armed = [];
    const keys = Object.keys(timeouts);
    for (var k = 0; k < keys.length; ++k) {
      const armedIn = keys[k];
      if (states.indexOf(armedIn) === -1) {
        Logger.w("StateMachine", machine.name + ": timeouts key", armedIn, "is not a state — spec dropped");
        continue;
      }
      const specs = timeouts[armedIn];
      for (var i = 0; i < specs.length; ++i) {
        if (states.indexOf(specs[i].to) === -1) {
          Logger.w("StateMachine", machine.name + ": timeout in", armedIn, "targets unknown state", specs[i].to, "— spec dropped");
          continue;
        }
        const spec = specs[i];
        const t = _timerProto.createObject(machine);
        const captured = spec;
        t.triggered.connect(function () {
          machine._onTimeout(captured);
        });
        armed.push({
                     "armedIn": armedIn,
                     "spec": spec,
                     "timer": t
                   });
      }
    }
    _armedTimers = armed;

    if (machine.name !== "") {
      if (_registeredName !== "") {
        // The name binding already put a row in during construction —
        // refresh it with the validated initial state + real enteredAt
        // instead of warning about a re-register.
        StateRegistry.update(_registeredName, state, "", _enteredAt);
      } else {
        _registeredName = _claimName();
        StateRegistry.register(_registeredName, state, _enteredAt);
      }
    }
    _rearm();
  }

  Component.onDestruction: {
    if (_registeredName !== "")
      StateRegistry.unregister(_registeredName);
  }
}
