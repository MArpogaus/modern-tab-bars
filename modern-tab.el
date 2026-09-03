;;; modern-tab.el --- The common part of modern-tab-bars -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Marcel Arpogaus

;; Author: Marcel Arpogaus <znepry.necbtnhf@tznvy.pbz>
;; Assisted-by: Claude:claude-opus-5
;; Version: 0.1
;; Package-Requires: ((emacs "29.1"))
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

;; Two minor modes that give the two rows of tabs Emacs has the look of
;; the editors people come here from: a coloured bar beside the selected
;; tab, an icon on every tab, and — on the tab line — a close button
;; that buries a buffer another window shows and kills one no window
;; does.
;;
;;   `modern-tab-bar-mode'   the tab bar, one tab per tab group
;;   `modern-tab-line-mode'  the tab line, one tab per window buffer
;;
;; The two are independent — turn on either.  The indicator options
;; carry matching names in both; the icon options do not, because a tab
;; group is named by a string and a tab of the tab line by a buffer.
;;
;; This file is the common one: the indicator beside a tab, the glyph
;; fallback, the icon table and the way a mode gives Emacs its
;; variables back.  It is also the package's main file, which is why it
;; carries the name the whole package is prefixed with: package-lint
;; takes that prefix from the main file, and `modern-tab-bar-mode' and
;; `modern-tab-line-mode' both live under `modern-tab-'.
;;
;; Icons come from nerd-icons where it is installed and the frame has
;; the font.  A graphic frame without the font falls back to a plain
;; character: `font-at' answers for the font that will really draw.  A
;; terminal is only asked whether it can encode the character, so a
;; UTF-8 terminal without a nerd font shows a box rather than a
;; fallback — name plain strings in the icon options there.

;;; Code:

(require 'seq)

(defgroup modern-tab nil
  "A modern look for the tab bar and the tab line."
  :group 'convenience
  :prefix "modern-tab-")

;;;; The bar beside a tab

(defvar modern-tab--indicators (make-hash-table :test #'equal)
  "The bar images built so far, keyed on height, width and colour.
Nothing invalidates them: a theme brings another colour, which is
another key.")

(defun modern-tab--color (spec)
  "Return the colour SPEC names, or nil for none.
SPEC is a colour name, or a face whose foreground is the colour.  The
default face ends the chain: a terminal theme often leaves a face
without a foreground of its own, and nil is not a colour."
  (cond ((null spec) nil)
        ((facep spec) (face-foreground spec nil 'default))
        (t spec)))

(defun modern-tab-indicator (height width color)
  "Return a bar of HEIGHT and WIDTH pixels, drawn in COLOR.
WIDTH of nil or zero is no bar at all, and the answer is then the empty
string.  COLOR is a colour name or a face, as `modern-tab--color'
takes it.

A frame without images — a terminal, or one built without PBM — draws
one column of a vertical line instead.  Thanks to doom-modeline for the
idea."
  (let ((color (modern-tab--color color)))
    (cond
     ((or (null width) (zerop width)) "")
     ((and (display-graphic-p) (image-type-available-p 'pbm))
      ;; A handful of these exist in a session, one per height, width
      ;; and colour, and building one means a fresh payload string and
      ;; a spec the image cache then compares whole.
      (with-memoization (gethash (list height width color) modern-tab--indicators)
        (propertize " " 'display
                    (create-image
                     (concat (format "P1\n%i %i\n" width height)
                             (make-string (* width height) ?1) "\n")
                     'pbm t :foreground color :ascent 'center))))
     ;; A face attribute of nil is not "leave it alone", it is an error
     ;; the display logs on every redisplay.  A bar without a colour
     ;; wears no face and takes the one of the row it sits in.
     (t (propertize "|" 'face (and color (list :foreground color
                                               :background color)))))))

;;;; Glyphs, and what a frame can draw

(defun modern-tab--drawable-p (string)
  "Return non-nil where this frame draws the first character of STRING.
The question is asked of STRING, so the face STRING carries is part of
it.  That is the point: a nerd-icons glyph names a font family of its
own, and asking whether the buffer's default font has the character
answers for a font that draws nothing here.

`font-at' answers with the font that will really draw the character:
the one the face names, the one a fallback finds, or nil where none
will.

A terminal has no font to ask, and `char-displayable-p' answers for the
coding system instead: a UTF-8 terminal says yes to a glyph it will
draw as a box.  There is nothing better to ask it."
  (and (stringp string)
       (not (string-empty-p string))
       (if (display-graphic-p)
           (font-at 0 nil string)
         (char-displayable-p (aref string 0)))))

(defun modern-tab-glyph (&rest candidates)
  "Return the first of CANDIDATES this frame can draw.
The last one is the answer where it can draw none of them, so keep a
plain character there.  nerd-icons answers with a glyph whether or not
the frame has the font, and such a glyph without the font is a hex
box."
  (or (seq-find #'modern-tab--drawable-p (butlast candidates))
      (car (last candidates))))

;;;; Icons

(defvar modern-tab--icons (make-hash-table :test #'equal)
  "The icon each key answered, kept per display.
A terminal and a graphic frame answer differently, and one session can
hold both.  `modern-tab-forget' empties this where the answer can
change: another icon list, or a font arriving.")

(defun modern-tab-forget (&rest _)
  "Forget the icons answered so far."
  (clrhash modern-tab--icons))

(defun modern-tab-set-and-forget (symbol value)
  "Set SYMBOL to VALUE and forget the icons answered before it changed.
A `:set' function for every option an icon depends on."
  (set-default symbol value)
  (modern-tab-forget))

(defun modern-tab--nerd-icon (spec)
  "Return the nerd-icons glyph SPEC names, or a plain character.
SPEC is a plist with `:style' and `:icon'.  The style is the middle of
a nerd-icons function name — \"oct\" for `nerd-icons-octicon', \"md\"
for `nerd-icons-mdicon' — and the icon is the glyph name without its
\"nf-<style>-\" front.  The \"suc\" style is the exception: its glyphs
are named \"nf-<icon>\", with no style in the middle.  Inspired by
nerd-icons-corfu."
  (let* ((style (plist-get spec :style))
         (icon (plist-get spec :icon))
         (fun (intern (concat "nerd-icons-" style "icon")))
         (name (if (equal style "suc")
                   (concat "nf-" icon)
                 (concat "nf-" style "-" icon))))
    (modern-tab-glyph (and (fboundp fun) (funcall fun name)) "?")))

(defun modern-tab-icon (spec)
  "Return SPEC as the string that shows on a tab.
A string stands for itself, a plist names a nerd icon, a function is
called for one, and nil is nothing.  The function is what a caller
whose lookup is expensive passes, so that `modern-tab-icon-for' can
leave it uncalled where it already has the answer."
  (cond ((null spec) "")
        ((stringp spec) spec)
        ((functionp spec) (funcall spec))
        (t (modern-tab--nerd-icon spec))))

(defun modern-tab-icon-for (key spec)
  "Return the icon SPEC names for KEY, and keep the answer.
A row of tabs is built again on every command, and finding a nerd icon
walks the table of its style — 6880 entries for the material design
one — so the answer is kept, per key and per display.

SPEC is read only where KEY has no answer yet: where it has one, SPEC
is ignored and the kept answer comes back, so a caller that changes
SPEC calls `modern-tab-forget' first.  A SPEC that is a function is not
called at all on a hit, which is how a caller keeps an expensive lookup
out of every redisplay."
  (with-memoization (gethash (list key (display-graphic-p))
                             modern-tab--icons)
    (modern-tab-icon spec)))

;;;; What a mode gives back when it is turned off

(defun modern-tab-restore (&rest symbols)
  "Give each of SYMBOLS the value its own customization says it has."
  (dolist (symbol symbols)
    (custom-reevaluate-setting symbol)))

(provide 'modern-tab)
;;; modern-tab.el ends here
