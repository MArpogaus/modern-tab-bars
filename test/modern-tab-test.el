;;; modern-tab-test.el --- Tests for modern-tab -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Marcel Arpogaus

;; Author: Marcel Arpogaus <znepry.necbtnhf@tznvy.pbz>
;; URL: https://github.com/MArpogaus/modern-tab

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

;; Run with: make test

;;; Code:

(require 'ert)
(require 'modern-tab)

(ert-deftest modern-tab-test-compose ()
  "The greeting uses the configured word."
  (should (equal (modern-tab--compose "World") "Hello, World!"))
  (let ((modern-tab-greeting "Moin"))
    (should (equal (modern-tab--compose "World") "Moin, World!"))))

(ert-deftest modern-tab-test-mode-toggles ()
  "The mode turns on and off again."
  (modern-tab-mode 1)
  (should modern-tab-mode)
  (modern-tab-mode -1)
  (should-not modern-tab-mode))

(provide 'modern-tab-test)
;;; modern-tab-test.el ends here
