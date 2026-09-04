;;; modern-tab-bar.el --- A modern look for the tab bar -*- lexical-binding: t; -*-

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

;; `modern-tab-bar-mode' gives the tab bar a bar beside the selected tab
;; group, an icon for each group, and a new button and a close button
;; whose glyphs are the best ones the frame can draw.  Every part of the
;; look is an option; the indicator options match those of
;; `modern-tab-line-mode' name for name.

;;; Code:

(require 'tab-bar)
(require 'modern-tab)

(defgroup modern-tab-bar nil
  "A modern look for the tab bar."
  :group 'modern-tab
  :prefix "modern-tab-bar-")

;;;; Customization

(defcustom modern-tab-bar-indicator-height 25
  "Height of the bar beside a tab group, in pixels."
  :type 'natnum)

(defcustom modern-tab-bar-active-indicator-width 4
  "Width of the bar beside the selected tab group, in pixels.
Nil or zero draws no bar at all."
  :type '(choice natnum (const :tag "None" nil)))

(defcustom modern-tab-bar-inactive-indicator-width 2
  "Width of the bar beside a tab group that is not selected, in pixels.
Nil or zero draws no bar at all."
  :type '(choice natnum (const :tag "None" nil)))

(defcustom modern-tab-bar-active-indicator-color 'mode-line-emphasis
  "Colour of the bar beside the selected tab group.
A colour name, or a face whose foreground is the colour."
  :type '(choice color face (const :tag "None" nil)))

(defcustom modern-tab-bar-inactive-indicator-color 'shadow
  "Colour of the bar beside a tab group that is not selected.
A colour name, or a face whose foreground is the colour."
  :type '(choice color face (const :tag "None" nil)))

(defcustom modern-tab-bar-icons '(("HOME" :style "suc" :icon "custom-emacs"))
  "Alist of the icon each tab group shows.
The car of an entry is a regular expression matched against the name of
the group; the cdr is a string shown as it is, or a plist with `:style'
and `:icon', which names a nerd-icons glyph.  The first entry that
matches wins, and a group that matches none shows
`modern-tab-bar-default-icon'."
  :type '(alist :key-type regexp
                :value-type (choice string function
                                    (plist :key-type symbol
                                           :value-type string)))
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-bar-default-icon '(:style "oct" :icon "dot_fill")
  "Icon shown for a tab group that matches no entry of the alist.
See `modern-tab-bar-icons' for the values this takes."
  :type '(choice string function (plist :key-type symbol :value-type string))
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-bar-group-name-function nil
  "Function that returns the name to show for a tab group.
It is called with the name of the group and returns the string that
goes onto the tab bar.  Nil shows the name as it is."
  :type '(choice (const :tag "The name as it is" nil) function))

(defcustom modern-tab-bar-new-command #'tab-bar-new-tab
  "Command the new button of the tab bar runs."
  :type 'function)

(defcustom modern-tab-bar-new-glyphs '("  " " + ")
  "Glyphs of the button that makes a tab, best first.
A graphic frame shows the first one; a terminal takes the first it can
encode that is no private use glyph, so keep a plain string last."
  :type '(repeat string)
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-bar-close-glyphs '(" ✕ " " × " " x ")
  "Glyphs of the close button, best first.
A graphic frame shows the first one; a terminal takes the first it can
encode that is no private use glyph, so keep a plain character last."
  :type '(repeat string)
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-bar-menu-glyphs '("󰍜 " "≡ " " Menu ")
  "Glyphs of the menu button, best first.
A graphic frame shows the first one; a terminal takes the first it can
encode that is no private use glyph, so keep a plain string last."
  :type '(repeat string)
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-bar-current-glyphs '("󰅂 " "› " "  ")
  "Glyphs that mark the selected tab, best first.
A graphic frame shows the first one; a terminal takes the first it can
encode that is no private use glyph.  The last resort here is two
spaces, as wide as the glyphs before them."
  :type '(repeat string)
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-bar-format
  '(tab-bar-format-tabs-groups
    modern-tab-bar-format-new-button
    tab-bar-format-align-right
    tab-bar-format-global
    modern-tab-bar--thin-spacer
    modern-tab-bar--menu-bar
    modern-tab-bar--wide-spacer)
  "What the tab bar shows, as `tab-bar-format' takes it."
  :type 'hook)

;;;; The parts of the bar

(defun modern-tab-bar-new-button ()
  "Return the string of the new button, drawn for this display.
Per redisplay and not once at enable: `modern-tab-icon-for' keeps the
answer per display, so a daemon serving a graphic frame and a terminal
frame gives each the glyph it can draw, and a reader who customizes
`modern-tab-bar-new-glyphs' sees the new one at the next redisplay."
  (modern-tab-icon-for 'new-button
                       (lambda ()
                         (apply #'modern-tab-glyph
                                modern-tab-bar-new-glyphs))))

(defun modern-tab-bar-close-button ()
  "Return the string of the close button, drawn for this display.
The `close-tab' property is what the tab bar dispatches a click on it
on.  See `modern-tab-bar-new-button' for why it is not settled once."
  (propertize (modern-tab-icon-for 'close-button
                                   (lambda ()
                                     (apply #'modern-tab-glyph
                                            modern-tab-bar-close-glyphs)))
              'close-tab t
              'help-echo "Click to close tab"))

(defun modern-tab-bar-format-new-button ()
  "Return the tab bar button that runs `modern-tab-bar-new-command'.
A `tab-bar-format' can name this function.  The button wears the face
of the row it sits in, which is the look a bar of this package keeps:
the menu button beside it carries `default' because a theme can leave
the row's face without contrast, and an unreadable word is worse than
a blended one."
  `((add-tab menu-item ,(modern-tab-bar-new-button)
             ,modern-tab-bar-new-command
             :help "New")))

(defun modern-tab-bar--spacer (width)
  "Return a space of WIDTH for the tab bar.
WIDTH is a factor of the normal width of a space, as in the
`space-width' display property.  A terminal draws no part of a cell,
and one `space-width' item in the format leaves the whole row of the
bar unpainted there: the row then still shows what stood in it before.
A terminal gets no menu button either, which is what these spaces pad."
  (when (display-graphic-p)
    (propertize " " 'display `(space-width ,width))))

(defun modern-tab-bar--thin-spacer ()
  "Return a thin space for `modern-tab-bar-format'."
  (modern-tab-bar--spacer 0.1))

(defun modern-tab-bar--wide-spacer ()
  "Return a wide space for `modern-tab-bar-format'."
  (modern-tab-bar--spacer 0.75))

(defun modern-tab-bar--menu-bar ()
  "Return the menu button of the tab bar, and nothing in a terminal.
A terminal paints the row of the bar in the redisplay that turns the
bar on.  With the menu button in the row, a tab that changes before
that redisplay leaves the row blank for the rest of the session, and
neither `force-mode-line-update' nor `redraw-display' brings it back.
Measured with Emacs 30.2, in tmux 3.7 and under pyte.  A terminal
reaches the menu with \\[menu-bar-open] in any case.

The question is asked per redisplay and not once at enable, so a
daemon that serves a graphic frame and a terminal frame answers it for
each of them."
  (when (display-graphic-p)
    ;; The button is built here rather than taken from
    ;; `tab-bar-format-menu-bar', whose string carries
    ;; `tab-bar-tab-inactive': a face meant for a tab, and in a bar
    ;; this package draws it is the colour of neither the bar nor a
    ;; tab — measured with doom-one, the word "Menu" could not be
    ;; read at all.  But no face at all will not do either: a string
    ;; with none wears the face of the row it sits in, and a reader's
    ;; theme can leave that face without any contrast of its own —
    ;; measured with doom-one-light, the tab bar face was #f0f0f0 on
    ;; #f0f0f0, and the row swallowed the button whole.  So both
    ;; buttons of this bar wear `default', the one face every theme
    ;; keeps readable.
    `((menu-bar menu-item
                ,(propertize
                  (modern-tab-icon-for
                   'menu-button
                   (lambda () (apply #'modern-tab-glyph
                                     modern-tab-bar-menu-glyphs)))
                  'face 'default)
                tab-bar-menu-bar :help "Menu bar"))))

(defun modern-tab-bar--group-icon (name)
  "Return the icon for the tab group NAME.
The patterns are matched with the case rules of the reader who wrote
them, not with those of whatever buffer redisplay happens to be in:
`string-match-p' honours a buffer-local `case-fold-search', so \"HOME\"
claimed \"[P] homelab\" in most buffers and not in others."
  (let ((name (or name "")))
    (modern-tab-icon-for
     ;; The key says which row asked: one table serves both, and a tab
     ;; group and a buffer can carry the same name.
     (cons 'group name)
     (or (cdr (seq-find (lambda (entry)
                          (let ((case-fold-search nil))
                            (string-match-p (car entry) name)))
                        modern-tab-bar-icons))
         modern-tab-bar-default-icon))))

(defun modern-tab-bar-group-format (tab _index &optional selected)
  "Return the tab bar entry for the group of TAB.
SELECTED is non-nil for the group of the current tab.  This is what
`tab-bar-tab-group-format-function' is set to."
  (let ((name (funcall tab-bar-tab-group-function tab))
        (face (if selected 'tab-bar-tab-group-current
                'tab-bar-tab-group-inactive)))
    (concat (modern-tab-indicator
             modern-tab-bar-indicator-height
             (if selected modern-tab-bar-active-indicator-width
               modern-tab-bar-inactive-indicator-width)
             (if selected modern-tab-bar-active-indicator-color
               modern-tab-bar-inactive-indicator-color))
            (propertize (concat " " (modern-tab-bar--group-icon name) " "
                                (if (functionp modern-tab-bar-group-name-function)
                                    (funcall modern-tab-bar-group-name-function
                                             name)
                                  name)
                                " ")
                        'face face))))

(defun modern-tab-bar-name-format (tab index)
  "Return the tab bar entry for TAB, the one numbered INDEX.
This is what `tab-bar-tab-name-format-function' is set to."
  (let ((selected (eq (car tab) 'current-tab)))
    (propertize
     (concat (if selected
                 (modern-tab-icon-for
                  'current-glyph
                  (lambda ()
                    (apply #'modern-tab-glyph
                           modern-tab-bar-current-glyphs)))
               " ")
             (if tab-bar-tab-hints (format "%d " index) "")
             (alist-get 'name tab)
             ;; `tab-bar-close-button-show' is four-valued, and reading
             ;; it as a boolean showed the button on the selected tab
             ;; for `non-selected', which is the other way round.
             (if (memq tab-bar-close-button-show
                       (if selected '(t selected) '(t non-selected)))
                 (modern-tab-bar-close-button) " "))
     ;; The face the tab bar itself would use, which is where
     ;; `tab-bar-tab-inactive', `tab-bar-tab-ungrouped' and a reader's
     ;; own `tab-bar-tab-face-function' live.  Naming `tab-bar-tab'
     ;; here drew every tab in the selected tab's colours.
     ;; No `mouse-face' here: `tab-bar-tab-highlight' painted a cyan
     ;; block under the pointer that the modern look does not want.
     'face (list :inherit (funcall tab-bar-tab-face-function tab)
                 :weight (if selected 'bold 'normal)))))

;;;; The mode

(defun modern-tab-bar--setup ()
  "Give the tab bar the modern look."
  ;; The buttons and the menu entry are drawn per redisplay, by
  ;; `modern-tab-bar-new-button', `modern-tab-bar-close-button' and
  ;; `modern-tab-bar--menu-bar': settled here they would be settled for
  ;; one display, and for the glyphs the options held at the enable.
  (modern-tab-borrow 'modern-tab-bar-mode
                     'tab-bar-format 'tab-bar-separator
                     'tab-bar-auto-width
                     'tab-bar-tab-group-format-function
                     'tab-bar-tab-name-format-function)
  (setq tab-bar-format modern-tab-bar-format
        tab-bar-separator ""
        tab-bar-auto-width nil
        tab-bar-tab-group-format-function #'modern-tab-bar-group-format
        tab-bar-tab-name-format-function #'modern-tab-bar-name-format))

(defun modern-tab-bar--teardown ()
  "Give the tab bar back what it had before the mode."
  (modern-tab-give-back 'modern-tab-bar-mode))

;;;###autoload
(define-minor-mode modern-tab-bar-mode
  "Give the tab bar a modern look, with an icon for each tab group.
The bar itself is the reader's: turn it on with `tab-bar-mode', which
this mode neither enables nor disables.  Turning this mode off puts
every tab bar variable back as it was found, so the stock look returns
on the next redisplay."
  :global t
  :group 'modern-tab-bar
  (if modern-tab-bar-mode
      (modern-tab-bar--setup)
    (modern-tab-bar--teardown))
  (modern-tab-forget))

(provide 'modern-tab-bar)
;;; modern-tab-bar.el ends here
