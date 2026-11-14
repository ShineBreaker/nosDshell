pragma Singleton

import QtQuick
import Quickshell

// Live registry of NStateMachine instances — the machine-readable view of
// every explicit lifecycle in the shell. Machines push {state, previous,
// enteredAt} rows on each transition; this is plain data, so a destroyed
// machine can never dangle a live object here.
//
// Consumers:
//   * ShellState.buildStateSnapshot() folds snapshot() into the IPC
//     `state all` dump — agents and `debug get` sessions read live phases
//     instead of inferring them from flag combinations.
//   * `state all` output is also what makes an illegal transition visible:
//     a rejected edge leaves the machine parked in the wrong phase for the
//     reader to see.
Singleton {
  id: root

  // {name: {"state": s, "previous": p, "enteredAt": ms}}
  property var _table: ({})

  // Bumped on every table change so bindings watching `revision` refresh.
  readonly property int revision: _revision
  property int _revision: 0

  function has(name) {
    return !!_table[name];
  }

  function register(name, state, enteredAt) {
    if (_table[name]) {
      Logger.w("StateRegistry", "name re-registered:", name, "— overwriting row");
    }
    _setRow(name, state, "", enteredAt);
  }

  function update(name, state, previous, enteredAt) {
    _setRow(name, state, previous, enteredAt);
  }

  function unregister(name) {
    if (!_table[name])
      return;
    const next = Object.assign({}, _table);
    delete next[name];
    _table = next;
    _revision++;
  }

  function _setRow(name, state, previous, enteredAt) {
    const next = Object.assign({}, _table);
    next[name] = {
      "state": state,
      "previous": previous,
      "enteredAt": enteredAt
    };
    _table = next;
    _revision++;
  }

  // Plain-JS deep copy, safe to JSON.stringify for IPC.
  function snapshot() {
    const copy = {};
    const keys = Object.keys(_table);
    for (var i = 0; i < keys.length; ++i) {
      const row = _table[keys[i]];
      copy[keys[i]] = {
        "state": row.state,
        "previous": row.previous,
        "enteredAt": row.enteredAt
      };
    }
    return copy;
  }
}
