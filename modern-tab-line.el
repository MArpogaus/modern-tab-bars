;;; modern-tab-line.el --- A modern look for the tab line -*- lexical-binding: t; -*-

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

;; `modern-tab-line-mode' gives the tab line a bar beside the selected
;; tab, an icon for each buffer, and a close button that buries the
;; buffer where another window still shows it, kills it where none
;; does, and deletes the window with its last tab.  Every part of the
;; look is an option; the indicator options match those of
;; `modern-tab-bar-mode' name for name.

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
  :type '(choice (const :tag "None" nil) function)
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-line-close-glyphs '(" " "✕ " "× " "x ")
  "Glyphs of the close button, best first.
A graphic frame shows the first one; a terminal takes the first it can
encode that is no private use glyph, so keep a plain character last."
  :type '(repeat string)
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-line-auto-hide t
  "Whether a window showing one buffer hides its tab line.
A row of tabs with a single tab on it says nothing, and it costs a line
of every window."
  :type 'boolean
  :set (lambda (symbol value)
         (set-default symbol value)
         ;; A change takes effect at once, in both directions: the
         ;; rows this package hid come back, and the decision is then
         ;; made again, which does nothing where VALUE is nil.  The
         ;; option can be set while this file is still loading, so
         ;; the functions below it are asked for first.
         (when (fboundp 'modern-tab-line--show-everywhere)
           (modern-tab-line--show-everywhere)
           (modern-tab-line-update-frame))))

;;;; The parts of a tab

(defun modern-tab-line-file-icon (buffer)
  "Return the nerd-icons glyph for the name of BUFFER.
The name is what nerd-icons is asked about, as though it were a file
name, so a buffer visiting no file still gets the icon its name earns.
Nothing where nerd-icons is not installed, and a plain character where
the frame cannot draw the glyph.

The lookup is handed over rather than done: `modern-tab-icon-for' calls
it only where it has no answer for this name yet, and a row of tabs is
built again on every command."
  (when (fboundp 'nerd-icons-icon-for-file)
    (let ((name (buffer-name buffer)))
      (modern-tab-icon-for
       ;; The key says which row asked: one table serves both.
       (cons 'buffer name)
       (lambda ()
         (modern-tab-glyph (nerd-icons-icon-for-file name) ""))))))

(defun modern-tab-line--buffer (tab)
  "Return the buffer TAB stands for, or nil where it stands for none.
A tab is a buffer or an alist, and `tab-line-tabs-function' is public:
a reader can set it to a function that answers with neither."
  (cond ((bufferp tab) tab)
        ((consp tab) (cdr (assq 'buffer tab)))))

(defun modern-tab-line-close-button ()
  "Return the close button of the tab line, drawn for this display.
Per redisplay and not once at enable: `modern-tab--button' keeps the
answer per kind of display, so a daemon serving a graphic frame and a
terminal frame gives each the glyph it can draw.  Settled at enable it
was settled for the display the enable happened on — and a daemon
enables its modes with no frame at all, where the answer is a
terminal's."
  (propertize (modern-tab--button 'line-close-button
                                 modern-tab-line-close-glyphs)
              'keymap tab-line-tab-close-map
              'mouse-face 'tab-line-close-highlight
              'help-echo "Click to close tab"))

(defun modern-tab-line-tab-name (buffer &optional _buffers)
  "Return the name shown on the tab of BUFFER, with its icon.
This is what `tab-line-tab-name-function' is set to.  The indicator is
not here: see `modern-tab-line-tab-format'."
  (let ((icon (and modern-tab-line-icon-function
                   (funcall modern-tab-line-icon-function buffer))))
    (concat " "
            (if (and icon (not (string-empty-p icon))) (concat icon " ") "")
            (buffer-name buffer)
            " ")))

(defun modern-tab-line-tab-format (tab tabs)
  "Return TAB, one of TABS, as the row draws it, indicator first.
This is what `tab-line-tab-name-format-function' is set to.

The indicator is not in `modern-tab-line-tab-name', because
`tab-line-tab-name-format-default' propertizes the whole name it
formats with the face of the row and `propertize' overwrites a face: a
terminal indicator, which carries its colour in a face of its own, came
out in the colour of the row.  The image form of a graphic frame
survived, which is why this only showed in a terminal.

`tab-line-close-button' is bound here rather than set at enable, so
that the row of every frame gets the glyph that frame can draw.  See
`modern-tab-line-close-button'."
  (let ((selected (eq (modern-tab-line--buffer tab) (window-buffer)))
        (tab-line-close-button (modern-tab-line-close-button)))
    (concat (modern-tab-indicator
             modern-tab-line-indicator-height
             (if selected modern-tab-line-active-indicator-width
               modern-tab-line-inactive-indicator-width)
             (if selected modern-tab-line-active-indicator-color
               modern-tab-line-inactive-indicator-color))
            (tab-line-tab-name-format-default tab tabs))))

;;;; Closing a tab

(defvar modern-tab-line--dying nil
  "A buffer on its way out, whose tab no longer counts.
`kill-buffer-hook' runs while the buffer is still live and still in the
buffer lists of every window, so it says which one is going.")

(defun modern-tab-line--several-p ()
  "Return non-nil where the selected window has more than one tab.
The tabs are the ones the row shows, which `tab-line-tabs-function'
says: a reader may have set it to another of the stock functions, or to
a list of their own.  The buffer of `modern-tab-line--dying' does not
count."
  (length> (seq-remove (lambda (tab)
                         (and modern-tab-line--dying
                              (eq (modern-tab-line--buffer tab)
                                  modern-tab-line--dying)))
                       (funcall tab-line-tabs-function))
           1))

(defun modern-tab-line-close-tab (tab)
  "Bury or kill the buffer of TAB, and delete the window with its last tab.
The buffer is buried where another window still shows it and killed
where none does."
  (interactive (list (current-buffer)))
  (let ((window (selected-window))
        (last (not (modern-tab-line--several-p)))
        (buffer (modern-tab-line--buffer tab)))
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

(defun modern-tab-line-update-window (&optional window)
  "Show the tab line in WINDOW only where it has tabs.
WINDOW is the selected window by default.  A window is decided here
only where its parameter is still nil, or where the `none' there is
this package's own doing: the hiding leaves the `modern-tab-line-hide'
parameter behind as the mark of its own.  A `none' another package set
— `auto-side-windows' hides the side panels this way — is not this
package's to undo: this hides rows, it does not take the row over."
  (let* ((window (or window (selected-window)))
         (param (window-parameter window 'tab-line-format)))
    (when (and modern-tab-line-auto-hide
               (or (null param)
                   (and (eq param 'none)
                        (window-parameter window 'modern-tab-line-hide))))
      (let ((hide (not (with-selected-window window
                         (modern-tab-line--several-p)))))
        (set-window-parameter
         window 'tab-line-format (if hide 'none nil))
        (set-window-parameter window 'modern-tab-line-hide hide)))))

(defun modern-tab-line-update-frame (&rest _)
  "Ask every window of every frame whether to show its tab line.
Every frame, because a frame that is not the selected one keeps its
rows until something changes its windows, and a row of one tab says
nothing there either."
  (when modern-tab-line-auto-hide
    (walk-windows #'modern-tab-line-update-window 'no-mini t)))

(defun modern-tab-line--buffer-killed ()
  "Ask every window about its tab line, less the buffer that is going.
On `kill-buffer-hook', which is the only word of the one case no window
change function reports: a buffer that no window shows leaves the
buffer lists of the windows that remember it, and no window changes.
The hook runs before the buffer goes, so its own tab is discounted."
  (let ((modern-tab-line--dying (current-buffer)))
    (modern-tab-line-update-frame)))

(defun modern-tab-line--show-everywhere ()
  "Take the hiding off every window that this package hid.
The `modern-tab-line-hide' parameter marks the windows whose `none'
this package set, and the parameter has to say `none' still: where
another value took its place, the decision was somebody else's.  A
hiding another package left, such as the `none' `auto-side-windows'
puts on a side panel, is left alone."
  (walk-windows (lambda (window)
                  (when (and (eq (window-parameter window 'tab-line-format)
                                 'none)
                             (window-parameter window 'modern-tab-line-hide))
                    (set-window-parameter window 'tab-line-format nil)
                    (set-window-parameter window 'modern-tab-line-hide nil)))
                'no-mini t))

;;;; The mode

(defun modern-tab-line--setup ()
  "Give the tab line the modern look."
  ;; The three things that change what a window's row of tabs holds.
  ;; `buffer-list-update-hook' was here before: it runs on every
  ;; `get-buffer-create', `set-buffer' and `kill-buffer' — about twice
  ;; per buffer operation — and each run walked the buffer lists of a
  ;; window for a count that had not changed.
  (add-hook 'window-buffer-change-functions #'modern-tab-line-update-frame)
  (add-hook 'window-configuration-change-hook #'modern-tab-line-update-frame)
  (add-hook 'kill-buffer-hook #'modern-tab-line--buffer-killed)
  (modern-tab--borrow 'modern-tab-line-mode
                     'tab-line-tab-name-function
                     'tab-line-tab-name-format-function
                     'tab-line-close-tab-function
                     'tab-line-separator
                     'tab-line-new-button-show
                     'tab-line-close-button-show)
  (setq tab-line-tab-name-function #'modern-tab-line-tab-name
        tab-line-tab-name-format-function #'modern-tab-line-tab-format
        tab-line-close-tab-function #'modern-tab-line-close-tab
        tab-line-separator ""
        tab-line-new-button-show nil
        tab-line-close-button-show 'selected)
  (modern-tab-line-update-frame))

(defun modern-tab-line--teardown ()
  "Give the tab line back what it had before the mode."
  (remove-hook 'window-buffer-change-functions #'modern-tab-line-update-frame)
  (remove-hook 'window-configuration-change-hook
               #'modern-tab-line-update-frame)
  (remove-hook 'kill-buffer-hook #'modern-tab-line--buffer-killed)
  ;; Nothing borrowed is a mode that was never on: it hid no row, and
  ;; its teardown must give nothing back.
  (when (modern-tab--give-back 'modern-tab-line-mode)
    (modern-tab-line--show-everywhere)))

;;;###autoload
(define-minor-mode modern-tab-line-mode
  "Give the tab line a modern look, with an icon for each buffer.
The row itself is the reader's: turn it on with `tab-line-mode' or
`global-tab-line-mode', which this mode neither enables nor disables —
the way `modern-tab-bar-mode' leaves `tab-bar-mode' alone.  Turning
this mode off puts every tab line variable back as it was found, so the
stock look returns on the next redisplay."
  :global t
  :group 'modern-tab-line
  (if modern-tab-line-mode
      (modern-tab-line--setup)
    (modern-tab-line--teardown))
  ;; Rows already drawn live in each window's `tab-line-cache', keyed on
  ;; nothing this package sets: without this, the old look stays until a
  ;; window's tabs change on their own.
  (modern-tab-forget))

(provide 'modern-tab-line)
;;; modern-tab-line.el ends here
