;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 BrokenShine <xchai404@gmail.com>
;;;
;;; 开发回环入口：`guix build -f guix.scm' 构建本工作树的 nosdshell
;;; （不经过 git pin）。包定义本体在 nosd-pkgs channel 的
;;; guix/nosd/packages.scm——分发设施已从本仓迁出，这里只把
;;; pinned source 换成当前 checkout。
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
             (guix build utils)
             (nosd packages))

(define %source-dir
  ;; guix.scm 所在的 packages/nosdshell/ 目录即源码根。
  (dirname (current-filename)))

(package
  (inherit nosdshell)
  (source (local-file %source-dir
                      "nosdshell-source-checkout"
                      #:recursive? #t
                      #:select? (git-predicate %source-dir))))
