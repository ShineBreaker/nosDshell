import QtQuick

// Shared "request → countdown → fire" cycle, built on NStateMachine. Used by
// the session menu and the lock-screen power row, which previously carried
// two hand-copied copies of the same machine (timerActive + pendingAction +
// timeRemaining + a 100 ms tick Timer, ~30 lines each).
//
// States: idle → counting → idle (expiry, confirm, or cancel all land there).
// A second start() with the same action fires immediately — the double-click
// confirm both call sites had.
//
//   ActionCountdown {
//     id: countdown
//     name: "countdown:sessionMenu@" + (root.screen?.name || "?")
//     duration: Settings.data.sessionMenu.countdownDuration
//     onTriggered: action => root.executeAction(action)
//   }
QtObject {
  id: root

  // Countdown length in ms. Read live on every start().
  required property int duration

  // Registry/log tag forwarded to the inner machine. Empty = unregistered.
  property string name: ""

  readonly property bool timerActive: fsm.is("counting")
  readonly property string pendingAction: _pending
  readonly property int timeRemaining: _remaining

  // The action must execute now — expiry, confirm, or countdown-disabled
  // immediate path all end here.
  signal triggered(string action)

  property string _pending: ""
  property int _remaining: 0

  function start(action) {
    if (fsm.is("counting") && _pending === action) {
      fire();
      return;
    }
    _pending = action;
    _remaining = duration;
    // force: starting over with a different action re-enters counting so the
    // tick restarts at a full duration.
    fsm.transition("counting", true);
  }

  function cancel() {
    _reset();
    fsm.transition("idle", true);
  }

  // Fire the pending action and return to idle. Also reachable from a
  // counting state when the caller wants immediate execution.
  function fire() {
    if (!fsm.is("counting"))
      return;
    const action = _pending;
    _reset();
    // Reset BEFORE emitting so a triggered() handler reads idle state.
    fsm.transition("idle", true);
    triggered(action);
  }

  function _reset() {
    _pending = "";
    _remaining = 0;
  }

  // QtObject has no default property for children — the machine goes into
  // a declared property (same reason NStateMachine uses property Component
  // for its timeout timers).
  property NStateMachine _fsm: NStateMachine {
    id: fsm
    name: root.name
    states: ["idle", "counting"]
    state: "idle"
    transitions: ({
                    "idle": ["counting"],
                    "counting": ["idle"]
                  })
    onEntered: state => {
      if (state === "counting")
        tick.restart();
      else
        tick.stop();
    }
  }

  property Timer _tick: Timer {
    id: tick
    interval: 100
    repeat: true
    onTriggered: {
      root._remaining -= interval;
      if (root._remaining <= 0)
        root.fire();
    }
  }
}
