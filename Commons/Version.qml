pragma Singleton

import QtQuick
import Quickshell

Singleton {
  // Version constants for display (About page) and diagnostics.
  // Keep baseVersion in sync with the package version in nosdshell.scm.
  readonly property string baseVersion: "4.6.1"
  readonly property bool isDevelopment: true
  readonly property string developmentSuffix: "-git"
  readonly property string currentVersion: `v${!isDevelopment ? baseVersion : baseVersion + developmentSuffix}`
}
