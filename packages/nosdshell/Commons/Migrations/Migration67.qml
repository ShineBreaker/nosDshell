import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v67 (dead lock-screen toggles removed)");

    // DDE always shows the power button on the lock screen, and hibernate is
    // governed by sessionMenu.powerOptions plus system capability — the old
    // Noctalia toggles no longer gate anything.
    if (rawJson.general) {
      delete rawJson.general.showSessionButtonsOnLockScreen;
      delete rawJson.general.showHibernateOnLockScreen;
    }

    return true;
  }
}
