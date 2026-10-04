import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v62 (DDE 15 session menu / OSD / bubble layout)");

    // §3.8 — the session menu became the dde-shutdown full-screen row. Existing
    // users keep their own powerOptions order/enabled flags; fresh installs get
    // the DDE order. The Noctalia layout keys stay but are inert.
    var options = rawJson && rawJson.sessionMenu ? rawJson.sessionMenu.powerOptions : null;
    if (!options || !Array.isArray(options) || options.length === 0) {
      // Nothing to reorder (or a hand-written config); leave the default alone.
      logger.i("Settings", "No existing sessionMenu.powerOptions, keeping DDE default order");
    } else {
      logger.i("Settings", "Keeping existing sessionMenu.powerOptions order:", options.length, "entries");
    }

    // §3.7 — the OSD tile moved to the DDE position (bottom centre, 180 px above
    // the screen bottom). The old value was the plain "bottom" edge anchor.
    var osd = rawJson && rawJson.osd ? rawJson.osd : {};
    if (osd.location === "bottom") {
      adapter.osd.location = "bottom_center";
      logger.i("Settings", "Migrated osd.location: bottom_center");
    }

    // §3.6 — normal notifications now use the bubbleTimeout-derived 5 s
    // (DESIGN §1.7) instead of Noctalia's 8 s.
    var notif = rawJson && rawJson.notifications ? rawJson.notifications : {};
    if (notif.normalUrgencyDuration === 8) {
      adapter.notifications.normalUrgencyDuration = 5;
      logger.i("Settings", "Migrated notifications.normalUrgencyDuration: 5");
    }

    // §3.6 — DDE shows one bubble at a time and queues the rest; the value only
    // exists from v62 onward, so it comes from the default (1). Nothing to read.
    logger.i("Settings", "notifications.maxVisible defaults to", adapter.notifications.maxVisible);

    return true;
  }
}
