;;; modern-tab-line.el --- A modern look for the tab line -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Marcel Arpogaus

;; Author: Marcel Arpogaus <znepry.necbtnhf@tznvy.pbz>
;; Assisted-by: Claude:claude-opus-5
;; Keywords: convenience, tabs
;; URL: https://github.com/MArpogaus/modern-tab-bars

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

;; `modern-tab-line-mode' gives the tab line a bar beside the selected
;; tab, an icon for each buffer, and a close button that closes what an
;; editor would close: the buffer, unless another window shows it, and
;; the window when its last tab goes.  Every part of the look is an
;; option, and every option matches one of `modern-tab-bar-mode'.

;;; Code:

(require 'tab-line)
(require 'modern-tab)

(defgroup modern-tab-line nil
  "A modern look for the tab line."
  :group 'modern-tab
  :prefix "modern-tab-line-")

;;;; Customization

(defcustom modern-tab-line-indicator-height 20
  "Height of the bar beside a tab, in pixels."
  :type 'natnum)

(defcustom modern-tab-line-active-indicator-width 3
  "Width of the bar beside the selected tab, in pixels.
Nil or zero draws no bar at all."
  :type '(choice natnum (const :tag "None" nil)))

(defcustom modern-tab-line-inactive-indicator-width 0
  "Width of the bar beside a tab that is not selected, in pixels.
Nil or zero draws no bar at all."
  :type '(choice natnum (const :tag "None" nil)))

(defcustom modern-tab-line-active-indicator-color 'mode-line-emphasis
  "Colour of the bar beside the selected tab.
A colour name, or a face whose foreground is the colour."
  :type '(choice color face (const :tag "None" nil)))

(defcustom modern-tab-line-inactive-indicator-color 'shadow
  "Colour of the bar beside a tab that is not selected.
A colour name, or a face whose foreground is the colour."
  :type '(choice color face (const :tag "None" nil)))

(defcustom modern-tab-line-icon-function #'modern-tab-line-file-icon
  "Function that returns the icon of a tab, called with its buffer.
Nil shows no icon at all."
  :type '(choice (const :tag "None" nil) function))

(defcustom modern-tab-line-close-glyphs '("✕ " "x ")
  "Glyphs of the close button, best first.
The first one the frame can draw wins, so keep a plain character last."
  :type '(repeat string))

(defcustom modern-tab-line-auto-hide t
  "Whether a window showing one buffer hides its tab line.
A row of tabs with a single tab on it says nothing, and it costs a line
of every window."
  :type 'boolean)

;;;; The parts of a tab

(defun modern-tab-line-file-icon (buffer)
  "Return the nerd-icons glyph for the file BUFFER visits.
Nothing where nerd-icons is not installed, and a plain character where
the frame cannot draw the glyph."
  (when (fboundp 'nerd-icons-icon-for-file)
    (let ((name (buffer-name buffer)))
      (modern-tab-icon-for name
                               (modern-tab-glyph
                                (nerd-icons-icon-for-file name) "")))))

(defun modern-tab-line-tab-name (buffer &optional _buffers)
  "Return the name shown on the tab of BUFFER.
This is what `tab-line-tab-name-function' is set to."
  (let* ((icon (and modern-tab-line-icon-function
                    (funcall modern-tab-line-icon-function buffer)))
         (selected (eq buffer (window-buffer))))
    (concat (modern-tab-indicator
             modern-tab-line-indicator-height
             (if selected modern-tab-line-active-indicator-width
               modern-tab-line-inactive-indicator-width)
             (if selected modern-tab-line-active-indicator-color
               modern-tab-line-inactive-indicator-color))
            " "
            (if (and icon (not (string-empty-p icon))) (concat icon " ") "")
            (buffer-name buffer)
            " ")))

;;;; Closing a tab

(defun modern-tab-line--buffer (tab)
  "Return the buffer TAB stands for."
  (if (bufferp tab) tab (cdr (assq 'buffer tab))))

(defun modern-tab-line--several-p ()
  "Return non-nil where the selected window has more than one tab."
  (> (length (tab-line-tabs-window-buffers)) 1))

(defun modern-tab-line-close-tab (tab)
  "Close TAB the way an editor would.
The buffer is buried where another window still shows it and killed
where none does, and the window goes with its last tab."
  (interactive (list (current-buffer)))
  (let ((window (selected-window))
        (last (not (modern-tab-line--several-p)))
        (buffer (modern-tab-line--buffer tab)))
    (if (length> (get-buffer-window-list buffer nil t) 1)
        (bury-buffer)
      (kill-buffer buffer))
    (when last
      (ignore-errors (delete-window window)))))

;;;; Hiding a row that says nothing

(defun modern-tab-line-update-window ()
  "Show the tab line in the selected window only where it has tabs."
  (when modern-tab-line-auto-hide
    (set-window-parameter nil 'tab-line-format
                          (if (modern-tab-line--several-p) nil 'none))))

(defun modern-tab-line-update-frame ()
  "Ask every window of the selected frame whether to show its tab line."
  (when modern-tab-line-auto-hide
    (dolist (window (window-list))
      (with-selected-window window
        (modern-tab-line-update-window)))))

(defun modern-tab-line--show-everywhere ()
  "Take the hiding off every window of every frame."
  (dolist (frame (frame-list))
    (dolist (window (window-list frame))
      (set-window-parameter window 'tab-line-format nil))))

;;;; The mode

(defun modern-tab-line--setup ()
  "Give the tab line the modern look."
  (add-hook 'after-setting-font-hook #'modern-tab-forget)
  (add-hook 'buffer-list-update-hook #'modern-tab-line-update-window)
  (add-hook 'window-state-change-hook #'modern-tab-line-update-frame)
  (setq tab-line-tab-name-function #'modern-tab-line-tab-name
        tab-line-close-tab-function #'modern-tab-line-close-tab
        tab-line-separator ""
        tab-line-new-button-show nil
        tab-line-close-button-show 'selected
        tab-line-close-button
        (propertize (apply #'modern-tab-glyph modern-tab-line-close-glyphs)
                    'keymap tab-line-tab-close-map
                    'mouse-face 'tab-line-close-highlight
                    'help-echo "Click to close tab"))
  (global-tab-line-mode 1)
  (modern-tab-line-update-frame))

(defun modern-tab-line--teardown ()
  "Give the tab line its stock look back."
  (remove-hook 'after-setting-font-hook #'modern-tab-forget)
  (remove-hook 'buffer-list-update-hook #'modern-tab-line-update-window)
  (remove-hook 'window-state-change-hook #'modern-tab-line-update-frame)
  (modern-tab-line--show-everywhere)
  (modern-tab-restore 'tab-line-tab-name-function
                          'tab-line-close-tab-function
                          'tab-line-separator
                          'tab-line-new-button-show
                          'tab-line-close-button-show
                          'tab-line-close-button)
  (global-tab-line-mode -1))

;;;###autoload
(define-minor-mode modern-tab-line-mode
  "Give the tab line a modern look, with an icon for each buffer.
The tab line itself is turned on with this mode and off with it."
  :global t
  :group 'modern-tab-line
  (if modern-tab-line-mode
      (modern-tab-line--setup)
    (modern-tab-line--teardown)))

(provide 'modern-tab-line)
;;; modern-tab-line.el ends here
