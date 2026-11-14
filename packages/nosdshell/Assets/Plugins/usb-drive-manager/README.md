# USB Drive Manager

Built-in nosDshell taskbar and control center plugin for mounting, inspecting, and safely ejecting USB drives and removable storage.

## Capabilities

- **Live device detection.** Watches `udevadm monitor` block events and updates the taskbar icon when a drive is plugged in or removed.
- **Mount, unmount, and safe power-off.** Mounts and unmounts partitions via `udisksctl`, and powers off the parent disk (`udisksctl power-off`) on eject.
- **Storage usage bar.** Displays volume label, filesystem type, total size, mountpoint path, and used/free capacity for each mounted partition.
- **One-click file manager access.** Opens mounted drives in your configured file manager (`xdg-open`, `dolphin`, `thunar`, `nautilus`, or terminal file managers like `yazi` and `ranger`) or copies the mountpoint path to the clipboard.
- **Bulk actions.** Unmount or safely eject all connected drives at once from the popup footer or the right-click menu.

## Runtime dependencies

| Tool | Package | Purpose |
|---|---|---|
| `udisksctl` | `udisks` | Mount, unmount, and power off drives |
| `udevadm` | `eudev` or `systemd` | Block device hotplug monitoring |
| `lsblk` | `util-linux` | Partition and filesystem enumeration |
| `df` | `coreutils` | Used and available space reporting |
| `wl-copy` | `wl-clipboard` | Copy mountpoint path to clipboard (optional) |

## Settings

| Setting | Default | Description |
|---|---|---|
| Hide when empty | `true` | Hide the taskbar icon when no USB drives are connected |
| Mounted count badge | `false` | Show the number of mounted drives on the taskbar icon |
| Auto-mount | `false` | Mount USB partitions automatically when plugged in |
| Notifications | `true` | Show a toast when drives are mounted, unmounted, or ejected |
| File manager | `xdg-open` | Command used to open mounted drives |
| Terminal emulator | `kitty` | Terminal used when launching `yazi`, `ranger`, `lf`, or `nnn` |
| Icon color | `none` | Custom icon tint color |

## IPC

```bash
# Refresh the device list
qs -c nosdshell ipc call plugin:usb-drive-manager refresh

# Unmount all mounted USB partitions
qs -c nosdshell ipc call plugin:usb-drive-manager unmountAll
```

## Notes on NTFS volumes

Mounting NTFS partitions requires a working kernel driver (`ntfs3`) or `ntfs-3g`. If a volume was left dirty by Windows Fast Startup or hibernation, `udisksctl` refuses to mount it to prevent data corruption. Run `chkdsk` in Windows or disable Fast Startup to clear the dirty bit.
