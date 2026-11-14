;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 BrokenShine <xchai404@gmail.com>
;;;
;;; 开发回环入口：`guix build -f guix.scm' 构建本工作树的 nosdshell
;;; （不经过 git pin）。包定义本体在 nosd-pkgs channel 的
;;; guix/nosd/packages.scm——分发设施已从本仓迁出，这里把 nosdshell
;;; 及其三个 Rust 工具（同树演进，共享 source）的 pinned source 统一
;;; 换成当前 checkout；quickshell-nosd 是独立仓，保持 pin 不动。
;;;
;;; 用法（nosd monorepo 根为 ../..，nosd-pkgs 与其同级）：
;;;   guix build -L ../../../nosd-pkgs/guix -f guix.scm
;;;   guix shell -L ../../../nosd-pkgs/guix -f guix.scm  # 进运行环境
;;; 若 nosd-pkgs 已加入 ~/.config/guix/channels.scm，可省 -L：
;;;   guix time-machine -C channels.scm -- build -f guix.scm

(when (current-filename)
  (add-to-load-path (dirname (current-filename))))

(use-modules (guix gexp)
             (guix packages)
             (guix git-download)
             (nosd packages))

;; monorepo 根：guix.scm 位于 packages/nosdshell/。git-predicate 让
;; 未跟踪/未提交的改动也进构建（工作树语义），被 ignore 的产物除外。
(define %monorepo-root
  (dirname (dirname (dirname (current-filename)))))

(define %local-source
  (local-file %monorepo-root
              "nosd-checkout"
              #:recursive? #t
              #:select? (git-predicate %monorepo-root)))

(define (from-tree pkg)
  (package (inherit pkg) (source %local-source)))

(package
  (inherit nosdshell)
  (source %local-source)
  (inputs
   (modify-inputs (package-inputs nosdshell)
     (replace "nosd-blur" (from-tree nosd-blur))
     (replace "nosd-helpers" (from-tree nosd-helpers))
     (replace "nosd-theme" (from-tree nosd-theme)))))
