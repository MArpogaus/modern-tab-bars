;;; modern-tab-bar.el --- A modern look for the tab bar -*- lexical-binding: t; -*-

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

;; `modern-tab-bar-mode' gives the tab bar a bar beside the selected tab
;; group, an icon for each group, and buttons that read as buttons.
;; Every part of the look is an option, and every option matches one of
;; `modern-tab-line-mode'.

;;; Code:

(require 'icons)
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

(defcustom modern-tab-bar-indicator-width '(4 . 2)
  "Width of the bar beside a tab group, in pixels.
The car belongs to the selected group and the cdr to the others.
Either can be nil or zero, which draws no bar at all."
  :type '(cons (choice natnum (const :tag "None" nil))
               (choice natnum (const :tag "None" nil))))

(defcustom modern-tab-bar-indicator-color '(mode-line-emphasis . shadow)
  "Colour of the bar beside a tab group.
The car belongs to the selected group and the cdr to the others.  Each
is a colour name, or a face whose foreground is the colour."
  :type '(cons (choice color face (const :tag "None" nil))
               (choice color face (const :tag "None" nil))))

(defcustom modern-tab-bar-icons '(("HOME" :style "suc" :icon "custom-emacs"))
  "Alist of the icon each tab group shows.
The car of an entry is a regular expression matched against the name of
the group; the cdr is a string shown as it is, or a plist with `:style'
and `:icon', which names a nerd-icons glyph.  The first entry that
matches wins, and a group that matches none shows
`modern-tab-bar-default-icon'."
  :type '(alist :key-type regexp
                :value-type (choice string (plist :key-type symbol
                                                  :value-type string)))
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-bar-default-icon '(:style "oct" :icon "dot_fill")
  "Icon shown for a tab group that matches no entry of the alist.
See `modern-tab-bar-icons' for the values this takes."
  :type '(choice string (plist :key-type symbol :value-type string))
  :set #'modern-tab-set-and-forget)

(defcustom modern-tab-bar-group-name-function nil
  "Function that returns the name to show for a tab group.
It is called with the name of the group and returns the string that
goes onto the tab bar.  Nil shows the name as it is."
  :type '(choice (const :tag "The name as it is" nil) function))

(defcustom modern-tab-bar-new-command #'tab-bar-new-tab
  "Command the new button of the tab bar runs."
  :type 'function)

(defcustom modern-tab-bar-new-icon '((symbol "  ") (text " + "))
  "How the new button is drawn, as `define-icon' takes it."
  :type '(repeat sexp))

(defcustom modern-tab-bar-close-icon '((symbol " ✕ ") (text " x "))
  "How the close button is drawn, as `define-icon' takes it."
  :type '(repeat sexp))

(defcustom modern-tab-bar-current-glyphs '("󰅂 " " " "› ")
  "Glyphs that mark the selected tab, best first.
The first one the frame can draw wins, so keep a plain character last."
  :type '(repeat string))

(defcustom modern-tab-bar-format
  '(tab-bar-format-tabs-groups
    modern-tab-bar-format-new-button
    tab-bar-format-align-right
    tab-bar-format-global
    modern-tab-bar--thin-spacer
    tab-bar-format-menu-bar
    modern-tab-bar--wide-spacer)
  "What the tab bar shows, as `tab-bar-format' takes it."
  :type 'hook)

;;;; The parts of the bar

(defun modern-tab-bar-format-new-button ()
  "Return the tab bar button that runs `modern-tab-bar-new-command'.
A `tab-bar-format' can name this function."
  `((add-tab menu-item ,tab-bar-new-button ,modern-tab-bar-new-command
             :help "New")))

(defun modern-tab-bar--spacer (width)
  "Return a space of WIDTH for the tab bar.
WIDTH is a factor of the normal width of a space, as in the
`space-width' display property.  A terminal draws no part of a cell,
and one `space-width' item in the format leaves the whole row of the
bar unpainted there: the row then still shows what stood in it before.
A plain space says the same thing in a terminal."
  (if (display-graphic-p)
      (propertize " " 'display `(space-width ,width))
    " "))

(defun modern-tab-bar--thin-spacer ()
  "Return a thin space for `modern-tab-bar-format'."
  (modern-tab-bar--spacer 0.1))

(defun modern-tab-bar--wide-spacer ()
  "Return a wide space for `modern-tab-bar-format'."
  (modern-tab-bar--spacer 0.75))

(defun modern-tab-bar--format ()
  "Return `modern-tab-bar-format' for this display.
A terminal paints the row of the bar in the redisplay that turns the
bar on.  With the menu button in the format, a tab that changes before
that redisplay leaves the row blank for the rest of the session, and
neither `force-mode-line-update' nor `redraw-display' brings it back.
Measured with Emacs 30.2, in tmux 3.7 and under pyte.  A terminal
reaches the menu with \\[menu-bar-open] in any case."
  (if (display-graphic-p)
      modern-tab-bar-format
    (remq 'tab-bar-format-menu-bar modern-tab-bar-format)))

(defun modern-tab-bar--group-icon (name)
  "Return the icon for the tab group NAME.
The patterns are matched with the case rules of the reader who wrote
them, not with those of whatever buffer redisplay happens to be in:
`string-match-p' honours a buffer-local `case-fold-search', so \"HOME\"
claimed \"[P] homelab\" in most buffers and not in others."
  (modern-tab-icon-for
   name
   (or (cdr (seq-find (lambda (entry)
                        (let ((case-fold-search nil))
                          (string-match-p (car entry) name)))
                      modern-tab-bar-icons))
       modern-tab-bar-default-icon)))

(defun modern-tab-bar-group-format (tab _index &optional selected)
  "Return the tab bar entry for the group of TAB.
SELECTED is non-nil for the group of the current tab.  This is what
`tab-bar-tab-group-format-function' is set to."
  (let ((name (funcall tab-bar-tab-group-function tab))
        (face (if selected 'tab-bar-tab-group-current
                'tab-bar-tab-group-inactive)))
    (concat (modern-tab-indicator-for selected modern-tab-bar-indicator-height
                                    modern-tab-bar-indicator-width
                                    modern-tab-bar-indicator-color)
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
                 (apply #'modern-tab-glyph modern-tab-bar-current-glyphs)
               " ")
             (if tab-bar-tab-hints (format "%d " index) "")
             (alist-get 'name tab)
             ;; `tab-bar-close-button-show' is four-valued, and reading
             ;; it as a boolean showed the button on the selected tab
             ;; for `non-selected', which is the other way round.
             (if (memq tab-bar-close-button-show
                       (if selected '(t selected) '(t non-selected)))
                 tab-bar-close-button " "))
     'face (list :inherit 'tab-bar-tab :weight (if selected 'bold 'normal)))))

;;;; The mode

(defun modern-tab-bar--setup ()
  "Give the tab bar the modern look."
  (unless (iconp 'modern-tab-bar--new)
    (define-icon modern-tab-bar--new nil modern-tab-bar-new-icon
      "Icon of the button that makes a new tab."
      :version "29.1"
      :help-echo "New tab"))
  (unless (iconp 'modern-tab-bar--close)
    (define-icon modern-tab-bar--close nil modern-tab-bar-close-icon
      "Icon of the button that closes the tab it stands on."
      :version "29.1"
      :help-echo "Click to close tab"))
  (add-hook 'after-setting-font-hook #'modern-tab-forget)
  (setq tab-bar-new-button (icon-string 'modern-tab-bar--new)
        tab-bar-close-button (propertize (icon-string 'modern-tab-bar--close)
                                         'close-tab t)
        tab-bar-format (modern-tab-bar--format)
        tab-bar-separator ""
        tab-bar-auto-width nil
        tab-bar-tab-group-format-function #'modern-tab-bar-group-format
        tab-bar-tab-name-format-function #'modern-tab-bar-name-format))

(defun modern-tab-bar--teardown ()
  "Give the tab bar its stock look back."
  (remove-hook 'after-setting-font-hook #'modern-tab-forget)
  ;; There is no public way to restore the stock buttons; this is the
  ;; function that made them.
  (tab-bar--load-buttons)
  (modern-tab-restore 'tab-bar-separator
                          'tab-bar-auto-width
                          'tab-bar-tab-group-format-function
                          'tab-bar-tab-name-format-function
                          'tab-bar-format))

;;;###autoload
(define-minor-mode modern-tab-bar-mode
  "Give the tab bar a modern look, with an icon for each tab group."
  :global t
  :group 'modern-tab-bar
  (if modern-tab-bar-mode
      (modern-tab-bar--setup)
    (modern-tab-bar--teardown)))

(provide 'modern-tab-bar)
;;; modern-tab-bar.el ends here
