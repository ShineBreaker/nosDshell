;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025 Hilton Chain <hako@ultrarare.space>
;;; Copyright © 2026 BrokenShine <xchai404@gmail.com>
;;;
;;; Packaging for nosDshell, originally the Noctalia v4 recipe from the
;;; Rosenthal channel (https://codeberg.org/hako/Rosenthal).
;;;
;;; The shell installs to etc/xdg/quickshell/nosdshell and runs under our
;;; quickshell-nosd fork (see below); the nosd-blur wallpaper pre-blur tool is built
;;; from tools/nosd-blur via cargo-build-system, as are the nosd-helpers
;;; and nosd-theme Rust ports.  Their vendored crate sources live in
;;; nosdshell/rust-crates.scm (module (nosdshell rust-crates)).
;;;
;;; This repository doubles as a Guix channel (see .guix-channel): the
;;; package source is always the checkout this file lives in — the working
;;; tree under `guix build -f nosdshell.scm', the pinned channel commit
;;; after `guix pull'.  Sources therefore use local-file, never git-fetch.

;; `current-filename' is #f while this file is compiled as a channel
;; module (the compiler puts the channel root on the load path itself);
;; it resolves to the checkout path when loaded for `guix build -f' or
;; instantiated from the compiled channel.
(when (current-filename)
  (add-to-load-path (dirname (current-filename))))

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
  #:use-module (nosdshell rust-crates))

;; Where this file lives: the working tree under `guix build -f', or the
;; installed channel tree (share/guile/site/3.0, the whole checkout minus
;; .git) after `guix pull'.  current-filename is #f when this module is
;; instantiated from the compiled channel, so fall back to a load-path
;; lookup of our own source file.
(define %repo-root
  (dirname (or (current-filename)
               (search-path %load-path "nosdshell.scm")
               (error "cannot locate the nosdshell channel source"))))

;; A plain `guix build -f' or `guix pull' checkout carries .git (for file://
;; remotes a worktree .git file), so untracked files can be dropped via
;; git-predicate.  Channel sources compiled from a stripped tree have no
;; .git; they already contain only the wanted files, so select everything.
(define %git-checkout?
  (file-exists? (string-append %repo-root "/.git")))

(define (package-source subdir)
  (local-file (string-append %repo-root "/" subdir)
              #:recursive? #t
              #:select? (if %git-checkout?
                            (git-predicate
                             (string-append %repo-root "/" subdir))
                            (const #t))))


;;; Our quickshell fork (ShineBreaker/quickshell-nosd): upstream master at
;;; the version 0.3.2 commit plus the two pipewire use-after-free fixes the
;;; archived noctalia-qs fork carried and upstream never merged — dangling
;;; raw PwNode pointers in the default-device tracker (903a70a) and in the
;;; PwNodeIface-bound volume/peak readers (08e6406).  Both crash the shell
;;; when a pipewire node (USB audio, headphones) disappears; they are now
;;; real commits in the fork rather than patches applied here.
;;;
;;; Upstream's adjacent destructor-order fixes (36517a2, 91dcb41, 13fe9b0)
;;; do not remove the dangling-pointer windows, so both fixes are still
;;; needed.
;;;
;;; 5ff26dc adds one more fix on top: PR_SET_PDEATHSIG for managed child
;;; processes.  The shell spawns long-lived helpers (wl-paste clipboard
;;; watchers, niri event-stream, nmcli monitor, udevadm monitor) that must
;;; not outlive it; without the parent-death signal a crash or SIGTERM
;;; reparented them to init and they kept running as orphans.
(define quickshell/nosd
  (package
    (inherit quickshell)
    (name "quickshell-nosd")
    (version "0.3.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ShineBreaker/quickshell-nosd")
             (commit "5ff26dce11ba3a2ce4b9855c269964d6367f718c")))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1k7sk1qfw7gw4j8dj5adrm1s06qr1ipx4q6fxllka4dfvk8dfm51"))))))

(define-public nosd-blur
  (package
    (name "nosd-blur")
    (version "0.1.0")
    (source (package-source "tools/nosd-blur"))
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
    (source (package-source "tools/nosd-helpers"))
    (build-system cargo-build-system)
    (arguments
     (list #:install-source? #f
           #:phases
           #~(modify-phases %standard-phases
               ;; `portal run` is a darkman-compatible portal Settings
               ;; backend; shipping the activatable name plus the portal
               ;; descriptor makes `Settings=nosdshell` work out of the box
               ;; for any consumer that installs this package.
               (add-after 'install 'install-portal-files
                 (lambda _
                   (let ((services (in-vicinity #$output "share/dbus-1/services"))
                         (portals (in-vicinity #$output "share/xdg-desktop-portal/portals")))
                     (mkdir-p services)
                     (call-with-output-file
                         (in-vicinity services
                                      "org.freedesktop.impl.portal.desktop.nosdshell.service")
                       (lambda (p)
                         (format p "[D-BUS Service]~%\
Name=org.freedesktop.impl.portal.desktop.nosdshell~%\
Exec=~a/bin/nosd-helpers portal run~%"
                                 #$output)))
                     (mkdir-p portals)
                     (call-with-output-file
                         (in-vicinity portals "nosdshell.portal")
                       (lambda (p)
                         (format p "[portal]~%\
DBusName=org.freedesktop.impl.portal.desktop.nosdshell~%\
Interfaces=org.freedesktop.impl.portal.Settings~%\
UseIn=niri;sway;Hyprland;labwc;scroll;mangowc;~%")))))))))
    (inputs nosd-helpers-cargo-inputs)
    (home-page "https://github.com/ShineBreaker/nosDshell")
    (synopsis "Small helper tools for nosDshell")
    (description
     "nosd-helpers is the single Rust binary behind nosDshell's helper
subcommands (vscode-themes, kde-apply-scheme, gtk-refresh, khal-events,
bluetooth-pair, eds-check, eds-calendars,
eds-events, apply, wl-probe, vinput, portal).  QML callers require it; the
Scripts/python and Scripts/bash helpers were removed after the ports reached
parity.  The portal subcommand additionally ships a darkman-compatible
xdg-desktop-portal Settings backend.")
    (license license:gpl3+)))

(define-public nosd-theme
  (package
    (name "nosd-theme")
    (version "0.1.0")
    (source (package-source "tools/nosd-theme"))
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
    (version "1.7.1")
    (source (local-file %repo-root
                        #:recursive? #t
                        #:select? (if %git-checkout?
                                      (git-predicate %repo-root)
                                      (const #t))))
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
          (add-after 'install 'install-completions
            (lambda* (#:key source #:allow-other-keys)
              ;; completions/ holds one file per shell; install each under its
              ;; standard name so profiles pick it up automatically.
              ;; (New files must be committed: the package source only includes
              ;; git-tracked files, so staged-but-uncommitted files are invisible here.)
              (let ((share (string-append #$output "/share")))
                (mkdir-p (string-append share "/bash-completion/completions"))
                (mkdir-p (string-append share "/zsh/site-functions"))
                (mkdir-p (string-append share "/fish/vendor_completions.d"))
                (copy-file (string-append source "/completions/nosdshell.bash")
                           (string-append share "/bash-completion/completions/nosdshell"))
                (copy-file (string-append source "/completions/_nosdshell")
                           (string-append share "/zsh/site-functions/_nosdshell"))
                (copy-file (string-append source "/completions/nosdshell.fish")
                           (string-append share "/fish/vendor_completions.d/nosdshell.fish")))))
          (add-after 'install 'make-wrapper
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Write the wrapper straight into the output: the checkout
              ;; root holds a nosdshell/ directory (channel module path),
              ;; so a same-named scratch file here no longer works.
              (let ((script (in-vicinity #$output "bin/nosdshell")))
                (mkdir-p (dirname script))
                ;; --version/-V prints the shell and quickshell versions without
                ;; starting the shell (lowercase -v is quickshell's verbose flag
                ;; and must fall through). release.sh bumps the nosdshell version
                ;; below together with (version ...); keep the quickshell part in
                ;; sync with quickshell/nosd above.
                (with-output-to-file script
                  (lambda ()
                    (format #t "~
#!~a
if [ \"$1\" = \"--version\" ] || [ \"$1\" = \"-V\" ]; then
  echo \"nosdshell v1.7.1 (with quickshell v0.3.2 5ff26dc)\"
  exit 0
fi
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
                (chmod script #o555))))
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
