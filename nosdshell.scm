;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025 Hilton Chain <hako@ultrarare.space>
;;; Copyright © 2026 BrokenShine <xchai404@gmail.com>
;;;
;;; Packaging for nosDshell, originally the Noctalia v4 recipe from the
;;; Rosenthal channel (https://codeberg.org/hako/Rosenthal).
;;;
;;; The shell installs to etc/xdg/quickshell/nosdshell and runs under
;;; upstream quickshell; the nosd-blur wallpaper pre-blur tool is built
;;; from tools/nosd-blur via cargo-build-system, as are the nosd-helpers
;;; and nosd-theme Rust ports.  Their vendored crate sources live in
;;; packaging/rust-crates.scm.  The source is the
;;; local checkout (git-tracked files only) so `guix build -f nosdshell.scm'
;;; always packages the working tree; for a release build switch source
;;; back to a git-fetch of the tag.

(add-to-load-path (string-append (dirname (current-filename)) "/packaging"))

(define-module (nosdshell)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cargo)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages calendar)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages hardware)
  #:use-module (gnu packages imagemagick)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages polkit)
  #:use-module (gnu packages python)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages version-control)
  ;; quickshell lives here in current Guix; (gnu packages wm) only carries a
  ;; deprecated alias.
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages xdisorg)
  #:use-module (rust-crates))

(define %repo-root
  (dirname (current-filename)))


;;; Upstream quickshell plus the pipewire use-after-free fixes that the
;;; archived noctalia-qs fork carried and upstream never merged: dangling
;;; raw PwNode pointers in the default-device tracker (ecdc0b1) and in the
;;; PwNodeIface-bound volume/peak readers (587f531 minus its spectrum.hpp
;;; hunk, which is fork-only).  Both crash the shell when a pipewire node
;;; (USB audio, headphones) disappears.  The fork's third engine fix —
;;; diffUpdate reordering in core/model — is already upstream at v0.3.0.
;;;
;;; Pinned to v0.3.1 (not the channel's 0.3.0): upstream fixed exactly the
;;; dock-hover crash class there — ScreencopyView creation failure,
;;; screencopy buffer creation failure, and unsetting PopupAnchor.item.
;;; Both pipewire patches still apply verbatim (verified against the tag).
(define quickshell/nosd
  (package
    (inherit quickshell)
    (name "quickshell-nosd")
    (version "0.3.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://git.outfoxxed.me/quickshell/quickshell")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1mhpgy7zcyqmqj6h1b0fhbriimkp2563lkgcdj5ipr32krkgdd88"))
       (patches
        (list (local-file
               (string-append %repo-root
                              "/packaging/patches/quickshell-pipewire-default-tracker-qpointer.patch"))
              (local-file
               (string-append %repo-root
                              "/packaging/patches/quickshell-pipewire-node-iface-qpointer.patch"))))))))

(define-public nosd-blur
  (package
    (name "nosd-blur")
    (version "0.1.0")
    (source (local-file (string-append %repo-root "/tools/nosd-blur")
                        #:recursive? #t
                        #:select? (git-predicate
                                   (string-append %repo-root "/tools/nosd-blur"))))
    (build-system cargo-build-system)
    (arguments (list #:install-source? #f))
    (inputs nosd-blur-cargo-inputs)
    (home-page "https://github.com/ShineBreaker/nosDshell")
    (synopsis "Pre-blur wallpapers for nosDshell")
    (description
     "nosd-blur produces a cover-resized, blurred variant of a wallpaper at
exact screen size, so nosDshell surfaces (lock screen, launcher, session
menu) can skip a live blur pass and just draw the cached image.")
    (license license:expat)))

(define-public nosd-helpers
  (package
    (name "nosd-helpers")
    (version "0.1.0")
    (source (local-file (string-append %repo-root "/tools/nosd-helpers")
                        #:recursive? #t
                        #:select? (git-predicate
                                   (string-append %repo-root "/tools/nosd-helpers"))))
    (build-system cargo-build-system)
    (arguments (list #:install-source? #f))
    (inputs nosd-helpers-cargo-inputs)
    (home-page "https://github.com/ShineBreaker/nosDshell")
    (synopsis "Small helper tools for nosDshell")
    (description
     "nosd-helpers is the single Rust binary behind nosDshell's helper
subcommands (vscode-themes, kde-apply-scheme, gtk-refresh, khal-events,
bluetooth-pair, eds-check, eds-calendars,
eds-events, apply).  QML callers require it; the Scripts/python and
Scripts/bash helpers were removed after the ports reached parity.")
    (license license:gpl3+)))

(define-public nosd-theme
  (package
    (name "nosd-theme")
    (version "0.1.0")
    (source (local-file (string-append %repo-root "/tools/nosd-theme")
                        #:recursive? #t
                        #:select? (git-predicate
                                   (string-append %repo-root "/tools/nosd-theme"))))
    (build-system cargo-build-system)
    (arguments (list #:install-source? #f))
    (inputs nosd-theme-cargo-inputs)
    (home-page "https://github.com/ShineBreaker/nosDshell")
    (synopsis "Material theme processor for nosDshell")
    (description
     "nosd-theme is the Rust port of the former
Scripts/python/src/theming tree (template-processor.py plus lib/):
wallpaper color extraction, Material tonal schemes
and Matugen-compatible template rendering.")
    (license license:gpl3+)))

(define-public nosdshell
  (package
    (name "nosdshell")
    (version "4.6.1")
    (source (local-file %repo-root
                        #:recursive? #t
                        #:select? (git-predicate %repo-root)))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("." "etc/xdg/quickshell/nosdshell"))
      #:imported-modules
      `((guix build qt-utils)
        ,@%copy-build-system-modules)
      #:modules
      '((srfi srfi-26)
        (guix build copy-build-system)
        (guix build qt-utils)
        (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'reduce-output-size
            (lambda _
              (delete-file-recursively "Assets/Screenshots")))
          (add-after 'install 'embed-rfkill-path
            (lambda* (#:key inputs #:allow-other-keys)
              ;; rfkill lives in util-linux/sbin, which the wrapper PATH
              ;; does not cover; point the unblock call at the store path.
              (substitute* (string-append
                            #$output
                            "/etc/xdg/quickshell/nosdshell/Services/Networking/BluetoothService.qml")
                (("\\[\"rfkill\", \"unblock\", \"bluetooth\"\\]")
                 (string-append "[\"" (search-input-file inputs "sbin/rfkill")
                                "\", \"unblock\", \"bluetooth\"]")))))
          (add-after 'install 'make-wrapper
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((script "nosdshell"))
                (with-output-to-file script
                  (lambda ()
                    (format #t "~
#!~a
exec ~a --config ~a/etc/xdg/quickshell/nosdshell \"$@\"~%"
                            (search-input-file inputs "bin/sh")
                            (search-input-file inputs "bin/quickshell")
                            #$output)))
                (wrap-script script
                  `("PATH"
                    suffix
                    ,(map (compose dirname
                                   (cut search-input-file inputs <>))
                          '("bin/bluetoothctl"
                            "bin/brightnessctl"
                            "bin/cava"
                            "bin/cliphist"
                            "bin/convert"
                            "bin/ddcutil"
                            "bin/dbus-send"
                            "bin/elogind-inhibit"
                            "bin/fastfetch"
                            "bin/fc-list"
                            "bin/find"
                            "bin/getent"
                            "bin/git"
                            "bin/grep"
                            "bin/khal"
                            "bin/ls"
                            "bin/nmcli"
                            "bin/nosd-blur"
                            "bin/nosd-helpers"
                            "bin/nosd-theme"
                            "bin/pgrep"
                            "bin/pkill"
                            "bin/python3"
                            "bin/sh"
                            "bin/which"
                            "bin/wl-paste"
                            "bin/wlsunset"
                            "bin/wtype"))))
                (chmod script #o555)
                (install-file script (in-vicinity #$output "bin")))))
          (add-after 'make-wrapper 'qt-wrap
            (lambda args
              (apply wrap-all-qt-programs
                     #:qtbase #$(this-package-input "qtbase")
                     args))))))
    (inputs
     (list bash-minimal
           bluez
           brightnessctl
           cava
           cliphist
           coreutils-minimal
           ddcutil
           dbus
           elogind
           fastfetch-minimal
           findutils
           fontconfig
           git-minimal
           glibc
           grep
           guile-3.0
           imagemagick
           khal
           network-manager
           nosd-blur
           nosd-helpers
           nosd-theme
           procps
           python-minimal
           qtbase
           qtdeclarative
           qtmultimedia
           qtwayland
           quickshell/nosd
           util-linux
           which
           wl-clipboard
           wlsunset
           wtype))
    (home-page "https://github.com/ShineBreaker/nosDshell")
    (synopsis "Wayland desktop shell in the DDE 15 visual language")
    (description
     "nosDshell is a desktop shell for Wayland built on the @code{quickshell}
framework, derived from Noctalia v4.  It renders every part of the shell —
taskbar, launcher, control center, notifications, OSD, lock screen — in the
visual language of deepin 15 (DDE 15).  It supports compositors like
@code{niri}, @code{hyprland}, and @code{sway}.")
    (license license:gpl3+)))
nosdshell
