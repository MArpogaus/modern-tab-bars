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

(defcustom modern-tab-line-close-glyphs '("✕ " "× " "x ")
  "Glyphs of the close button, best first.
The first one the frame can draw *in the font of the row* wins, so
keep a plain character last.  `✕' has no glyph in most programming
fonts and a fallback font drew it in another weight and another
width; `×' is in almost all of them."
  :type '(repeat string)
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-line-auto-hide t
  "Whether a window showing one buffer hides its tab line.
A row of tabs with a single tab on it says nothing, and it costs a line
of every window."
  :type 'boolean
  :set (lambda (symbol value)
         (set-default symbol value)
         ;; Off while the mode is on used to leave every row that was
         ;; already hidden hidden for good.
         (unless value
           (when (fboundp 'modern-tab-line--show-everywhere)
             (modern-tab-line--show-everywhere)))))

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
Per redisplay and not once at enable: `modern-tab-icon-for' keeps the
answer per kind of display, so a daemon serving a graphic frame and a
terminal frame gives each the glyph it can draw.  Settled at enable it
was settled for the display the enable happened on — and a daemon
enables its modes with no frame at all, where the answer is a
terminal's."
  (propertize (modern-tab-icon-for
               'line-close-button
               (lambda () (apply #'modern-tab-glyph
                                 modern-tab-line-close-glyphs)))
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
WINDOW is the selected window by default.  A window whose parameter
says something else was set by somebody else, and it is left as it is:
this hides rows, it does not take the row over."
  (let ((window (or window (selected-window))))
    (when (and modern-tab-line-auto-hide
               (memq (window-parameter window 'tab-line-format) '(nil none)))
      (set-window-parameter
       window 'tab-line-format
       (if (with-selected-window window (modern-tab-line--several-p))
           nil 'none)))))

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
A window whose parameter says something else was set by somebody else,
and it is left alone."
  (walk-windows (lambda (window)
                  (when (eq (window-parameter window 'tab-line-format) 'none)
                    (set-window-parameter window 'tab-line-format nil)))
                'no-mini t))

;;;; The mode

(defvar modern-tab-line--had-the-row nil
  "Whether `global-tab-line-mode' was on before this mode turned it on.
It stays on where it was on: a reader who had the row does not lose it
because this mode was turned off.")

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
  ;; The row this mode found is remembered where this call is the one
  ;; that borrowed: a second enable would otherwise remember the row
  ;; the first one turned on.
  (when (modern-tab-borrow 'modern-tab-line-mode
                           'tab-line-tab-name-function
                           'tab-line-tab-name-format-function
                           'tab-line-close-tab-function
                           'tab-line-separator
                           'tab-line-new-button-show
                           'tab-line-close-button-show)
    (setq modern-tab-line--had-the-row global-tab-line-mode))
  (setq tab-line-tab-name-function #'modern-tab-line-tab-name
        tab-line-tab-name-format-function #'modern-tab-line-tab-format
        tab-line-close-tab-function #'modern-tab-line-close-tab
        tab-line-separator ""
        tab-line-new-button-show nil
        tab-line-close-button-show 'selected)
  (global-tab-line-mode 1)
  (modern-tab-line-update-frame))

(defun modern-tab-line--teardown ()
  "Give the tab line back what it had before the mode."
  (remove-hook 'window-buffer-change-functions #'modern-tab-line-update-frame)
  (remove-hook 'window-configuration-change-hook
               #'modern-tab-line-update-frame)
  (remove-hook 'kill-buffer-hook #'modern-tab-line--buffer-killed)
  ;; Nothing borrowed is a mode that was never on: it hid no row, and a
  ;; stock `global-tab-line-mode' is not this package's to switch off.
  (when (modern-tab-give-back 'modern-tab-line-mode)
    (modern-tab-line--show-everywhere)
    (unless modern-tab-line--had-the-row
      (global-tab-line-mode -1))))

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
