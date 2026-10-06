pragma Singleton

import Quickshell
import qs.Commons

Singleton {
  id: root

  function _formatMessage(...args) {
    var t = Time.getFormattedTimestamp();
    if (args.length > 1) {
      const maxLength = 14;
      var module = args.shift().substring(0, maxLength).padStart(maxLength, " ");
      return `\x1b[36m[${t}]\x1b[0m \x1b[35m${module}\x1b[0m ` + args.join(" ");
    } else {
      return `[\x1b[36m[${t}]\x1b[0m ` + args.join(" ");
    }
  }

  function _getStackTrace() {
    try {
      throw new Error("Stack trace");
    } catch (e) {
      return e.stack;
    }
  }

  // Whether a debug message passes the module allowlist in
  // Settings.data.debug.modules ("" = everything passes). The first arg is
  // the module tag whenever there is more than one arg.
  function _debugModuleAllowed(args) {
    var filter = (Settings?.data?.debug?.modules ?? "").trim();
    if (filter === "" || args.length < 2) {
      return true;
    }
    var module = String(args[0]);
    var wanted = filter.split(",");
    for (var i = 0; i < wanted.length; i++) {
      if (wanted[i].trim() === module) {
        return true;
      }
    }
    return false;
  }

  // Debug log: gated by Settings.isDebug, narrowed by the modules allowlist.
  function d(...args) {
    if (Settings?.isDebug && _debugModuleAllowed(args)) {
      var msg = _formatMessage(...args);
      console.debug(msg);
    }
  }

  // Info log (suppressed by debug.logLevel="warn" for a minimal stream;
  // debug mode always restores the full stream so nothing is lost)
  function i(...args) {
    if (!Settings?.isDebug && (Settings?.data?.debug?.logLevel ?? "info") === "warn") {
      return;
    }
    var msg = _formatMessage(...args);
    console.info(msg);
  }

  // Warning log (always visible)
  function w(...args) {
    var msg = _formatMessage(...args);
    console.warn(msg);
  }

  // Error log (always visible)
  function e(...args) {
    var msg = _formatMessage(...args);
    console.error(msg);
  }

  function callStack() {
    var stack = _getStackTrace();
    Logger.i("Debug", "--------------------------");
    Logger.i("Debug", "Current call stack");
    // Split the stack into lines and log each one
    var stackLines = stack.split('\n');
    for (var i = 0; i < stackLines.length; i++) {
      var line = stackLines[i].trim(); // Remove leading/trailing whitespace
      if (line.length > 0) {
        // Only log non-empty lines
        Logger.i("Debug", `- ${line}`);
      }
    }
    Logger.i("Debug", "--------------------------");
  }
}
