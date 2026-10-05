;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025 Hilton Chain <hako@ultrarare.space>
;;; Copyright © 2026 BrokenShine <xchai404@gmail.com>
;;;
;;; Packaging for nosDshell, originally the Noctalia v4 recipe from the
;;; Rosenthal channel (https://codeberg.org/hako/Rosenthal).
;;;
;;; The shell installs to etc/xdg/quickshell/nosdshell and runs under
;;; upstream quickshell; the nosd-blur wallpaper pre-blur tool is built
;;; from tools/nosd-blur via cargo-build-system.  The crate list below is
;;; generated from tools/nosd-blur/Cargo.lock with
;;;
;;;   guix import crate --lockfile=tools/nosd-blur/Cargo.lock nosd-blur
;;;
;;; and must be regenerated when the lockfile changes.  The source is the
;;; local checkout (git-tracked files only) so `guix build -f nosdshell.scm'
;;; always packages the working tree; for a release build switch source
;;; back to a git-fetch of the tag.

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
  #:use-module (gnu packages xdisorg))

(define %repo-root
  (dirname (current-filename)))

;;; nosd-blur crate sources — generated, do not edit by hand.

(define rust-adler2-2.0.1
  (crate-source "adler2" "2.0.1"
                "1ymy18s9hs7ya1pjc9864l30wk8p2qfqdi7mhhcc5nfakxbij09j"))

(define rust-autocfg-1.5.1
  (crate-source "autocfg" "1.5.1"
                "0lqasy5i30flcgih1b50kvsk6z32g09r1q4ql7q81pj6228jy0zj"))

(define rust-bitflags-2.13.2
  (crate-source "bitflags" "2.13.2"
                "01hbgjwvid66850fzi76mvn5f2bqycx6sf165ng1kfjqq9bl1v9x"))

(define rust-bytemuck-1.25.2
  (crate-source "bytemuck" "1.25.2"
                "15rp2m7j7kq22s76cbjwmrkd5r8lvacnm0mnrj013cnzka22x0wm"))

(define rust-byteorder-lite-0.1.0
  (crate-source "byteorder-lite" "0.1.0"
                "15alafmz4b9az56z6x7glcbcb6a8bfgyd109qc3bvx07zx4fj7wg"))

(define rust-cfg-if-1.0.5
  (crate-source "cfg-if" "1.0.5"
                "0026j56901nzjraap3da0a8njw42j66zcxnn6s2s9aa5bcblhxjf"))

(define rust-crc32fast-1.5.2
  (crate-source "crc32fast" "1.5.2"
                "0y0f955n2hr5a8rd9nw9sr23nhjc42ddx3bjc47dnlmqssgpk9q1"))

(define rust-fdeflate-0.3.7
  (crate-source "fdeflate" "0.3.7"
                "130ga18vyxbb5idbgi07njymdaavvk6j08yh1dfarm294ssm6s0y"))

(define rust-flate2-1.1.10
  (crate-source "flate2" "1.1.10"
                "1jvd2cl8j5hyf8imi62y1x7gwzz1hajirni0801yxhds1qp4wqvf"))

(define rust-image-0.25.8
  (crate-source "image" "0.25.8"
                "1rwill018gn2kwzv332kfs72ns0kwwnfxwacbhvk9lk9cwzfp7sj"))

(define rust-image-webp-0.2.4
  (crate-source "image-webp" "0.2.4"
                "1hz814csyi9283vinzlkix6qpnd6hs3fkw7xl6z2zgm4w7rrypjj"))

(define rust-miniz-oxide-0.8.9
  (crate-source "miniz_oxide" "0.8.9"
                "05k3pdg8bjjzayq3rf0qhpirq9k37pxnasfn4arbs17phqn6m9qz"))

(define rust-miniz-oxide-0.9.1
  (crate-source "miniz_oxide" "0.9.1"
                "0k2bgjzk2sbsynpsv4wizwxbqp6vs7g08y5anbkrh3l6a15bqgxn"))

(define rust-moxcms-0.7.11
  (crate-source "moxcms" "0.7.11"
                "15qa5znj029i7677l0hdv0lwmjggrg920bhjgs3cjvydb72mg5dc"))

(define rust-num-traits-0.2.19
  (crate-source "num-traits" "0.2.19"
                "0h984rhdkkqd4ny9cif7y2azl3xdfb7768hb9irhpsch4q3gq787"))

(define rust-png-0.18.1
  (crate-source "png" "0.18.1"
                "0qca282xp8a6d7mikxrwji3f52mjn4vnqxz2v9iz5adj665rnxk0"))

(define rust-pxfm-0.1.30
  (crate-source "pxfm" "0.1.30"
                "1slrnbxd0nc96sny6x50ss1sm9ci0gig0fp1w8mw0pkgm5prapfm"))

(define rust-quick-error-2.0.1
  (crate-source "quick-error" "2.0.1"
                "18z6r2rcjvvf8cn92xjhm2qc3jpd1ljvcbf12zv0k9p565gmb4x9"))

(define rust-simd-adler32-0.3.10
  (crate-source "simd-adler32" "0.3.10"
                "1sny4y2qa5mwyxx5x59ln2p02vsdh92004njlslnx98imjc9489s"))

(define rust-zlib-rs-0.6.8
  (crate-source "zlib-rs" "0.6.8"
                "04j158293bx73kv5pj1i89ai411q7fxc9zwk3wkpqgb9gj7fas5j"))

(define rust-zune-core-0.4.12
  (crate-source "zune-core" "0.4.12"
                "0jj1ra86klzlcj9aha9als9d1dzs7pqv3azs1j3n96822wn3lhiz"))

(define rust-zune-jpeg-0.4.21
  (crate-source "zune-jpeg" "0.4.21"
                "04r7g6y9jp7d4c9bq23rz3gwzlr1dsl7vdk4yly35bc4jf52rki9"))

;;; Equivalent of what `guix import -i' inserts under
;;; (define-cargo-inputs lookup-cargo-inputs (nosd-blur => ...)); kept as a
;;; plain list because the lookup table cannot be resolved across modules
;;; when building via `guix build -f'.
(define nosd-blur-cargo-inputs
  (list rust-adler2-2.0.1
        rust-autocfg-1.5.1
        rust-bitflags-2.13.2
        rust-bytemuck-1.25.2
        rust-byteorder-lite-0.1.0
        rust-cfg-if-1.0.5
        rust-crc32fast-1.5.2
        rust-fdeflate-0.3.7
        rust-flate2-1.1.10
        rust-image-0.25.8
        rust-image-webp-0.2.4
        rust-miniz-oxide-0.8.9
        rust-miniz-oxide-0.9.1
        rust-moxcms-0.7.11
        rust-num-traits-0.2.19
        rust-png-0.18.1
        rust-pxfm-0.1.30
        rust-quick-error-2.0.1
        rust-simd-adler32-0.3.10
        rust-zlib-rs-0.6.8
        rust-zune-core-0.4.12
        rust-zune-jpeg-0.4.21))

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
           nosd-blur
           python-minimal
           qtbase
           qtdeclarative
           qtmultimedia
           qtwayland
           quickshell
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
