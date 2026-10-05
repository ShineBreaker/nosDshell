import QtQuick
import Quickshell
import qs.Commons

QtObject {
  id: root

  function migrate(adapter, logger, rawJson) {
    // v56 ran migrate-colorschemes.py, which was removed once the Rust
    // ports replaced the python helpers; nothing left to execute.
    logger.i("Settings", "Skipping v56 color scheme migration (helper removed)");
    return true;
  }
}
