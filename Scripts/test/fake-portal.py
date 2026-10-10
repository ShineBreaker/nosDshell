#!/usr/bin/env python3
"""Fake xdg-desktop-portal Settings endpoint for verify.sh's dark-mode-system
scene.

Owns org.freedesktop.portal.Desktop on the verify run's private session bus
and implements just enough of org.freedesktop.portal.Settings for
DarkModeService:

  org.freedesktop.portal.Settings.ReadOne(s namespace, s key) -> v
      returns the current value (freedesktop color-scheme: 0/1/2)
  org.nosd.verify.FakePortal.Emit(u value)
      flips the stored value and emits the real Settings.SettingChanged
      signal -- the same thing a DE emits when its appearance pref toggles.

Usage: fake-portal.py [initial-uint32]   (default 1 = prefer-dark)
"""
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

APPEARANCE = "org.freedesktop.appearance"
KEY = "color-scheme"


class Portal(dbus.service.Object):
    def __init__(self, bus, path, initial):
        self.value = dbus.UInt32(initial)
        super().__init__(bus, path)

    @dbus.service.method("org.freedesktop.portal.Settings",
                         in_signature="ss", out_signature="v")
    def ReadOne(self, ns, key):
        print(f"[fakeportal] ReadOne({ns},{key}) -> {int(self.value)}", flush=True)
        return self.value

    @dbus.service.method("org.nosd.verify.FakePortal",
                         in_signature="u", out_signature="")
    def Emit(self, value):
        self.value = dbus.UInt32(value)
        print(f"[fakeportal] Emit -> SettingChanged {int(value)}", flush=True)
        self.SettingChanged(APPEARANCE, KEY, self.value)

    @dbus.service.signal("org.freedesktop.portal.Settings", signature="ssv")
    def SettingChanged(self, ns, key, val):
        pass


dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
# Keep the BusNames alive: they release the well-known names on GC. The
# second name is the Emit endpoint — the scene addresses it directly so the
# trigger never gets intercepted by a real portal racing for the well-known
# name.
name = dbus.service.BusName("org.freedesktop.portal.Desktop", bus)
ctl = dbus.service.BusName("org.nosd.verify.FakePortal", bus)
Portal(bus, "/org/freedesktop/portal/desktop",
       int(sys.argv[1]) if len(sys.argv) > 1 else 1)
print("[fakeportal] ready", flush=True)
GLib.MainLoop().run()
