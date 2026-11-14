import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v82 (brightness-card flag now gates the basic-page slider)");

    // In upstream the flag only controlled a dedicated brightness card that
    // defaulted off. In the DDE layout it gates the brightness slider on the
    // basic page, which users see today regardless of the flag — flip stored
    // copies to enabled so the slider does not silently disappear.
    var cards = adapter.controlCenter?.cards;
    if (cards) {
      for (var i = 0; i < cards.length; i++) {
        if (cards[i] && cards[i].id === "brightness-card" && !cards[i].enabled) {
          var entry = cards[i];
          entry.enabled = true;
          cards[i] = entry;
          logger.i("Settings", "controlCenter.cards: brightness-card re-enabled");
          break;
        }
      }
    }

    return true;
  }
}
