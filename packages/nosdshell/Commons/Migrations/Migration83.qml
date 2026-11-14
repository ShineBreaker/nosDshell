import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v83 (re-run the v82 brightness-card flip for stamped configs)");

    // v82 flips stored brightness-card flags back to enabled (in upstream the
    // flag gated a card that defaulted off; in the DDE layout it gates the
    // basic-page slider). v82 shipped without its registry entry, so every
    // config loaded between e6e17df42 and this fix was stamped
    // settingsVersion=82 without the migration ever running — the slider
    // silently disappeared for them. Re-running the same flip here is
    // idempotent for configs that did run v82 (none exist yet) and for
    // freshly-seeded ones (the flag defaults on); it only touches configs
    // still carrying a disabled flag, which is exactly the skipped cohort.
    // Users who deliberately disabled the card afterwards will need to
    // toggle it off once more — cheaper than a missing slider nobody can
    // explain.
    var cards = adapter.controlCenter?.cards;
    if (cards) {
      for (var i = 0; i < cards.length; i++) {
        if (cards[i] && cards[i].id === "brightness-card" && !cards[i].enabled) {
          var entry = cards[i];
          entry.enabled = true;
          cards[i] = entry;
          logger.i("Settings", "controlCenter.cards: brightness-card re-enabled (v83 re-run)");
          break;
        }
      }
    }

    return true;
  }
}
