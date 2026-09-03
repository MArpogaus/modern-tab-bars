;;; modern-tab.el --- One line that says what this does -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Marcel Arpogaus

;; Author: Marcel Arpogaus <znepry.necbtnhf@tznvy.pbz>
;; Version: 0.1
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience
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

;; Describe here what the package is for, and how to start using it.
;; This text is what `M-x describe-package' shows, so write it for
;; somebody who just found the package and wonders whether it helps.

;;; Code:

(defgroup modern-tab nil
  "One line that says what this does."
  :group 'convenience
  :prefix "modern-tab-")

;;;; Customization

(defcustom modern-tab-greeting "Hello"
  "Word the greeting starts with."
  :type 'string)

;;;; Internal functions

(defun modern-tab--compose (name)
  "Return the greeting for NAME."
  (format "%s, %s!" modern-tab-greeting name))

;;;; Commands

;;;###autoload
(defun modern-tab-greet (name)
  "Greet NAME in the echo area."
  (interactive (list (read-string "Name: " user-full-name)))
  (message "%s" (modern-tab--compose name)))

;;;; Minor mode

;;;###autoload
(define-minor-mode modern-tab-mode
  "Toggle the feature this package provides."
  :global t
  :group 'modern-tab
  (if modern-tab-mode
      (message "modern-tab enabled")
    (message "modern-tab disabled")))

(provide 'modern-tab)
;;; modern-tab.el ends here
