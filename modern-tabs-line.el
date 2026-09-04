;;; modern-tabs-line.el --- A modern look for the tab line -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Marcel Arpogaus

;; Author: Marcel Arpogaus <znepry.necbtnhf@tznvy.pbz>
;; Assisted-by: Claude:claude-opus-5
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

;; `modern-tabs-line-mode' gives the tab line a bar beside the selected
;; tab, an icon for each buffer, and a close button that buries the
;; buffer where another window still shows it, kills it where none
;; does, and deletes the window with its last tab.  Every part of the
;; look is an option; the indicator options match those of
;; `modern-tabs-bar-mode' name for name.

;;; Code:

(require 'tab-line)
(require 'modern-tabs)

(defgroup modern-tabs-line nil
  "A modern look for the tab line."
  :group 'modern-tabs
  :prefix "modern-tabs-line-")

;;;; Customization

(defcustom modern-tabs-line-indicator-height 20
  "Height of the bar beside a tab, in pixels."
  :type 'natnum)

(defcustom modern-tabs-line-active-indicator-width 3
  "Width of the bar beside the selected tab, in pixels.
Nil or zero draws no bar at all."
  :type '(choice natnum (const :tag "None" nil)))

(defcustom modern-tabs-line-inactive-indicator-width 0
  "Width of the bar beside a tab that is not selected, in pixels.
Nil or zero draws no bar at all."
  :type '(choice natnum (const :tag "None" nil)))

(defcustom modern-tabs-line-active-indicator-color 'mode-line-emphasis
  "Colour of the bar beside the selected tab.
A colour name, or a face whose foreground is the colour."
  :type '(choice color face (const :tag "None" nil)))

(defcustom modern-tabs-line-inactive-indicator-color 'shadow
  "Colour of the bar beside a tab that is not selected.
A colour name, or a face whose foreground is the colour."
  :type '(choice color face (const :tag "None" nil)))

(defcustom modern-tabs-line-icon-function #'modern-tabs-line-file-icon
  "Function that returns the icon of a tab, called with its buffer.
Nil shows no icon at all."
  :type '(choice (const :tag "None" nil) function)
  :set #'modern-tabs-set-and-forget)

(defcustom modern-tabs-line-close-glyphs '("✕ " "× " "x ")
  "Glyphs of the close button, best first.
A graphic frame shows the first one; a terminal takes the first it can
encode that is no private use glyph, so keep a plain character last."
  :type '(repeat string)
  :set #'modern-tabs-set-and-forget)

(defcustom modern-tabs-line-auto-hide t
  "Whether a window showing one buffer hides its tab line.
A row of tabs with a single tab on it says nothing, and it costs a line
of every window."
  :type 'boolean
  :set (lambda (symbol value)
         (set-default symbol value)
         ;; Off while the mode is on used to leave every row that was
         ;; already hidden hidden for good.
         (unless value
           (when (fboundp 'modern-tabs-line--show-everywhere)
             (modern-tabs-line--show-everywhere)))))

;;;; The parts of a tab

(defun modern-tabs-line-file-icon (buffer)
  "Return the nerd-icons glyph for the name of BUFFER.
The name is what nerd-icons is asked about, as though it were a file
name, so a buffer visiting no file still gets the icon its name earns.
Nothing where nerd-icons is not installed, and a plain character where
the frame cannot draw the glyph.

The lookup is handed over rather than done: `modern-tabs-icon-for' calls
it only where it has no answer for this name yet, and a row of tabs is
built again on every command."
  (when (fboundp 'nerd-icons-icon-for-file)
    (let ((name (buffer-name buffer)))
      (modern-tabs-icon-for
       ;; The key says which row asked: one table serves both.
       (cons 'buffer name)
       (lambda ()
         (modern-tabs-glyph (nerd-icons-icon-for-file name) ""))))))

(defun modern-tabs-line--buffer (tab)
  "Return the buffer TAB stands for, or nil where it stands for none.
A tab is a buffer or an alist, and `tab-line-tabs-function' is public:
a reader can set it to a function that answers with neither."
  (cond ((bufferp tab) tab)
        ((consp tab) (cdr (assq 'buffer tab)))))

(defun modern-tabs-line-close-button ()
  "Return the close button of the tab line, drawn for this display.
Per redisplay and not once at enable: `modern-tabs-icon-for' keeps the
answer per kind of display, so a daemon serving a graphic frame and a
terminal frame gives each the glyph it can draw.  Settled at enable it
was settled for the display the enable happened on — and a daemon
enables its modes with no frame at all, where the answer is a
terminal's."
  (propertize (modern-tabs-icon-for
               'line-close-button
               (lambda () (apply #'modern-tabs-glyph
                                 modern-tabs-line-close-glyphs)))
              'keymap tab-line-tab-close-map
              'mouse-face 'tab-line-close-highlight
              'help-echo "Click to close tab"))

(defun modern-tabs-line-tab-name (buffer &optional _buffers)
  "Return the name shown on the tab of BUFFER, with its icon.
This is what `tab-line-tab-name-function' is set to.  The indicator is
not here: see `modern-tabs-line-tab-format'."
  (let ((icon (and modern-tabs-line-icon-function
                   (funcall modern-tabs-line-icon-function buffer))))
    (concat " "
            (if (and icon (not (string-empty-p icon))) (concat icon " ") "")
            (buffer-name buffer)
            " ")))

(defun modern-tabs-line-tab-format (tab tabs)
  "Return TAB, one of TABS, as the row draws it, indicator first.
This is what `tab-line-tab-name-format-function' is set to.

The indicator is not in `modern-tabs-line-tab-name', because
`tab-line-tab-name-format-default' propertizes the whole name it
formats with the face of the row and `propertize' overwrites a face: a
terminal indicator, which carries its colour in a face of its own, came
out in the colour of the row.  The image form of a graphic frame
survived, which is why this only showed in a terminal.

`tab-line-close-button' is bound here rather than set at enable, so
that the row of every frame gets the glyph that frame can draw.  See
`modern-tabs-line-close-button'."
  (let ((selected (eq (modern-tabs-line--buffer tab) (window-buffer)))
        (tab-line-close-button (modern-tabs-line-close-button)))
    (concat (modern-tabs-indicator
             modern-tabs-line-indicator-height
             (if selected modern-tabs-line-active-indicator-width
               modern-tabs-line-inactive-indicator-width)
             (if selected modern-tabs-line-active-indicator-color
               modern-tabs-line-inactive-indicator-color))
            (tab-line-tab-name-format-default tab tabs))))

;;;; Closing a tab

(defvar modern-tabs-line--dying nil
  "A buffer on its way out, whose tab no longer counts.
`kill-buffer-hook' runs while the buffer is still live and still in the
buffer lists of every window, so it says which one is going.")

(defun modern-tabs-line--several-p ()
  "Return non-nil where the selected window has more than one tab.
The tabs are the ones the row shows, which `tab-line-tabs-function'
says: a reader may have set it to another of the stock functions, or to
a list of their own.  The buffer of `modern-tabs-line--dying' does not
count."
  (length> (seq-remove (lambda (tab)
                         (and modern-tabs-line--dying
                              (eq (modern-tabs-line--buffer tab)
                                  modern-tabs-line--dying)))
                       (funcall tab-line-tabs-function))
           1))

(defun modern-tabs-line-close-tab (tab)
  "Bury or kill the buffer of TAB, and delete the window with its last tab.
The buffer is buried where another window still shows it and killed
where none does."
  (interactive (list (current-buffer)))
  (let ((window (selected-window))
        (last (not (modern-tabs-line--several-p)))
        (buffer (modern-tabs-line--buffer tab)))
    (if (length> (get-buffer-window-list buffer nil t) 1)
        ;; Out of this window's rows, the way `tab-line-close-tab' does
        ;; it: the tabs come from the two buffer lists of the window,
        ;; and `bury-buffer' of a buffer that is not current touches
        ;; neither, so the tab stayed and the click did nothing.
        (if (eq buffer (current-buffer))
            (bury-buffer)
          (set-window-prev-buffers
           window (assq-delete-all buffer (window-prev-buffers window)))
          (set-window-next-buffers
           window (delq buffer (window-next-buffers window))))
      (kill-buffer buffer))
    ;; The window goes only where its tab really went, and never the
    ;; sole window of a frame.
    (when (and last (not (buffer-live-p buffer)))
      (ignore-errors (delete-window window)))))

;;;; Hiding a row that says nothing

(defun modern-tabs-line-update-window (&optional window)
  "Show the tab line in WINDOW only where it has tabs.
WINDOW is the selected window by default.  A window whose parameter
says something else was set by somebody else, and it is left as it is:
this hides rows, it does not take the row over."
  (let ((window (or window (selected-window))))
    (when (and modern-tabs-line-auto-hide
               (memq (window-parameter window 'tab-line-format) '(nil none)))
      (set-window-parameter
       window 'tab-line-format
       (if (with-selected-window window (modern-tabs-line--several-p))
           nil 'none)))))

(defun modern-tabs-line-update-frame (&rest _)
  "Ask every window of every frame whether to show its tab line.
Every frame, because a frame that is not the selected one keeps its
rows until something changes its windows, and a row of one tab says
nothing there either."
  (when modern-tabs-line-auto-hide
    (walk-windows #'modern-tabs-line-update-window 'no-mini t)))

(defun modern-tabs-line--buffer-killed ()
  "Ask every window about its tab line, less the buffer that is going.
On `kill-buffer-hook', which is the only word of the one case no window
change function reports: a buffer that no window shows leaves the
buffer lists of the windows that remember it, and no window changes.
The hook runs before the buffer goes, so its own tab is discounted."
  (let ((modern-tabs-line--dying (current-buffer)))
    (modern-tabs-line-update-frame)))

(defun modern-tabs-line--show-everywhere ()
  "Take the hiding off every window that this package hid.
A window whose parameter says something else was set by somebody else,
and it is left alone."
  (walk-windows (lambda (window)
                  (when (eq (window-parameter window 'tab-line-format) 'none)
                    (set-window-parameter window 'tab-line-format nil)))
                'no-mini t))

;;;; The mode

(defun modern-tabs-line--setup ()
  "Give the tab line the modern look."
  ;; The three things that change what a window's row of tabs holds.
  ;; `buffer-list-update-hook' was here before: it runs on every
  ;; `get-buffer-create', `set-buffer' and `kill-buffer' — about twice
  ;; per buffer operation — and each run walked the buffer lists of a
  ;; window for a count that had not changed.
  (add-hook 'window-buffer-change-functions #'modern-tabs-line-update-frame)
  (add-hook 'window-configuration-change-hook #'modern-tabs-line-update-frame)
  (add-hook 'kill-buffer-hook #'modern-tabs-line--buffer-killed)
  (modern-tabs-borrow 'modern-tabs-line-mode
                      'tab-line-tab-name-function
                      'tab-line-tab-name-format-function
                      'tab-line-close-tab-function
                      'tab-line-separator
                      'tab-line-new-button-show
                      'tab-line-close-button-show)
  (setq tab-line-tab-name-function #'modern-tabs-line-tab-name
        tab-line-tab-name-format-function #'modern-tabs-line-tab-format
        tab-line-close-tab-function #'modern-tabs-line-close-tab
        tab-line-separator ""
        tab-line-new-button-show nil
        tab-line-close-button-show 'selected)
  (modern-tabs-line-update-frame))

(defun modern-tabs-line--teardown ()
  "Give the tab line back what it had before the mode."
  (remove-hook 'window-buffer-change-functions #'modern-tabs-line-update-frame)
  (remove-hook 'window-configuration-change-hook
               #'modern-tabs-line-update-frame)
  (remove-hook 'kill-buffer-hook #'modern-tabs-line--buffer-killed)
  ;; Nothing borrowed is a mode that was never on: it hid no row, and
  ;; its teardown must give nothing back.
  (when (modern-tabs-give-back 'modern-tabs-line-mode)
    (modern-tabs-line--show-everywhere)))

;;;###autoload
(define-minor-mode modern-tabs-line-mode
  "Give the tab line a modern look, with an icon for each buffer.
The row itself is the reader's: turn it on with `tab-line-mode' or
`global-tab-line-mode', which this mode neither enables nor disables —
the way `modern-tabs-bar-mode' leaves `tab-bar-mode' alone.  Turning
this mode off puts every tab line variable back as it was found, so the
stock look returns on the next redisplay."
  :global t
  :group 'modern-tabs-line
  (if modern-tabs-line-mode
      (modern-tabs-line--setup)
    (modern-tabs-line--teardown))
  ;; Rows already drawn live in each window's `tab-line-cache', keyed on
  ;; nothing this package sets: without this, the old look stays until a
  ;; window's tabs change on their own.
  (modern-tabs-forget))

(provide 'modern-tabs-line)
;;; modern-tabs-line.el ends here
