;;; modern-tabs.el --- The entry point of modern-tabs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Marcel Arpogaus

;; Author: Marcel Arpogaus <znepry.necbtnhf@tznvy.pbz>
;; Assisted-by: Claude:claude-opus-5
;; Version: 0.1
;; Keywords: convenience, tabs
;; URL: https://github.com/MArpogaus/modern-tabs

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; The entry the package is installed and required by.  Loading it
;; turns on nothing: it brings in the two files that define the modes,
;;
;;   `modern-tab-bar-mode'   the tab bar, one tab per tab group
;;   `modern-tab-line-mode'  the tab line, one tab per window buffer
;;
;; both autoloaded, and leaves the rest to the reader: see the
;; Commentary of `modern-tab' for what the package draws and
;; `modern-tab-bar' and `modern-tab-line' for their options.  Turn the
;; modes on where the rows are wanted:
;;
;;   (use-package modern-tabs
;;     :vc (:url "https://github.com/MArpogaus/modern-tabs" :rev :newest)
;;     :hook ((after-init . modern-tab-bar-mode)
;;            (after-init . modern-tab-line-mode)))
;;
;; The id is `modern-tabs', the name of this repository, and the
;; symbols are prefixed `modern-tab-', after the file package-lint
;; reads as the main one.

;;; Code:

(require 'modern-tab-bar)
(require 'modern-tab-line)

(provide 'modern-tabs)
;;; modern-tabs.el ends here
