import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v81 (bar floating is its own flag)");

    // bar.barType narrows to simple/framed; the former "floating" value is
    // now the bar.floating flag so either form can float (DESIGN §3.13).
    // A pre-v45 leftover bar.floating already loads into the adapter and
    // counts as a deliberate choice — only the barType value migrates.
    if (rawJson?.bar?.barType === "floating") {
      adapter.bar.barType = "simple";
      adapter.bar.floating = true;
    } else {
      if (adapter.bar.barType !== "simple" && adapter.bar.barType !== "framed") {
        adapter.bar.barType = "simple";
      }
      if (rawJson?.bar?.floating === undefined) {
        adapter.bar.floating = false;
      }
    }

    logger.i("Settings", "Bar form:", adapter.bar.barType, "floating:", adapter.bar.floating);
    return true;
  }
}
