;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025 Hilton Chain <hako@ultrarare.space>
;;;
;;; Packaging recipe for the Noctalia v4 stack, copied verbatim from the
;;; Rosenthal channel (https://codeberg.org/hako/Rosenthal),
;;; modules/rosenthal/packages/wm.scm: noctalia-qs from commit 67a6395 and
;;; nosdshell 4.6.1 from commit 3f4240e (the last v4 release before
;;; upstream switched to the C++ meson build in 5.0.0).
;;;
;;; Kept as the packaging base for nosDshell; bump version/origin here once
;;; the rework is done.

(define-module (nosdshell)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix git-download)
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
  #:use-module (gnu packages xdisorg))

(define-public nosdshell
  (package
    (name "nosdshell")
    (version "4.6.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                     (url "https://github.com/ShineBreaker/nosDshell")
                     (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "12plnkf46ncw9cx5mh2di23jvwd0hbxayr5bjlaj9blz63r10cjs"))))
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
          (add-after 'unpack 'patch-references
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute* "Services/Power/IdleInhibitorService.qml"
                (("systemd-inhibit")
                 (search-input-file inputs "bin/elogind-inhibit")))))
          (add-after 'unpack 'reduce-output-size
            (lambda _
              (delete-file-recursively "Assets/Screenshots")))
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
                            "bin/fastfetch"
                            "bin/fc-list"
                            "bin/find"
                            "bin/getent"
                            "bin/git"
                            "bin/grep"
                            "bin/khal"
                            "bin/ls"
                            "bin/nmcli"
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
           quickshell
           python-minimal
           qtbase
           qtwayland
           which
           wl-clipboard
           wlsunset
           wtype))
    (home-page "https://github.com/ShineBreaker/nosDshell")
    (synopsis "Wayland desktop shell")
    (description
     "Noctalia is a minimal desktop shell designed for Wayland, built on the
@code{quickshell} framework.  It offers a customizable and clean user interface,
supporting various Wayland compositors like @code{niri}, @code{hyprland}, and
@code{sway}.")
    (license license:gpl3+)))
