;;; modern-tab-test.el --- Tests for modern-tab -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Marcel Arpogaus

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The suite runs in batch, where there is no graphic display: the bars
;; are then vertical lines rather than images, and every glyph falls
;; back to its plain candidate.  What is measured here is what does not
;; depend on the display — the shapes, the names, the hooks a mode
;; leaves behind — and the checks that do say so.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'modern-tab)
(require 'modern-tab-bar)
(require 'modern-tab-line)

;;;; The bar

(ert-deftest modern-tab-test-a-bar-of-no-width-is-nothing ()
  "A width of nil or zero draws no bar."
  (should (equal (modern-tab-indicator 20 nil "red") ""))
  (should (equal (modern-tab-indicator 20 0 "red") "")))

(ert-deftest modern-tab-test-a-terminal-bar-is-a-line ()
  "Without a graphic display the bar is one column of a vertical line."
  (skip-unless (not (display-graphic-p)))
  (let ((bar (modern-tab-indicator 20 3 "red")))
    (should (equal (substring-no-properties bar) "|"))
    (should (equal (get-text-property 0 'face bar)
                   '(:foreground "red" :background "red")))))

(ert-deftest modern-tab-test-a-bar-without-a-colour-wears-no-face ()
  "A face attribute of nil is an error the display logs, so there is none."
  (skip-unless (not (display-graphic-p)))
  (should-not (get-text-property 0 'face (modern-tab-indicator 20 3 nil))))

(ert-deftest modern-tab-test-a-colour-comes-from-a-name-or-a-face ()
  "A colour names itself; a face gives its foreground."
  (should (equal (modern-tab--color "#ff0000") "#ff0000"))
  (should (equal (modern-tab--color 'default)
                 (face-foreground 'default nil 'default)))
  (should-not (modern-tab--color nil)))

(ert-deftest modern-tab-test-a-tab-reads-the-option-of-its-state ()
  "Each state has its own width and its own colour.
The selected tab of the tab line takes a bar; the others take none,
which is what a width of zero asks for.  The bar comes from
`modern-tab-line-tab-format', which puts it in front of the name the
row formats: the face of a terminal bar would not survive the
`propertize' that formatting does."
  (skip-unless (not (display-graphic-p)))
  (let ((modern-tab-line-active-indicator-width 3)
        (modern-tab-line-inactive-indicator-width 0)
        (modern-tab-line-active-indicator-color "red")
        (modern-tab-line-icon-function nil)
        (tab-line-tab-name-function #'modern-tab-line-tab-name))
    (with-temp-buffer
      (set-window-buffer nil (current-buffer))
      (let* ((tabs (list (current-buffer) (get-buffer-create "*other*")))
             (selected (modern-tab-line-tab-format (car tabs) tabs))
             (other (modern-tab-line-tab-format (cadr tabs) tabs)))
        (should (equal (get-text-property 0 'face selected)
                       '(:foreground "red" :background "red")))
        (should (string-prefix-p "|" (substring-no-properties selected)))
        (should (string-prefix-p " " (substring-no-properties other)))))))

;;;; Glyphs and icons

(ert-deftest modern-tab-test-a-glyph-falls-back-to-the-last ()
  "The last candidate answers where the frame can draw none of them."
  (should (equal (modern-tab-glyph "" nil "x") "x"))
  ;; A plain character a terminal can draw wins over the ones after it.
  (should (equal (modern-tab-glyph "a" "b") "a")))

(ert-deftest modern-tab-test-a-private-use-glyph-is-refused-by-a-terminal ()
  "A terminal can encode a nerd glyph and has no font that draws it.
`char-displayable-p' answers for the coding system, so a UTF-8 terminal
says yes to a character it shows as a box."
  (skip-unless (not (display-graphic-p)))
  (should (modern-tab--private-use-p ?\uE000))
  (should (modern-tab--private-use-p ?\uF8FF))
  (should (modern-tab--private-use-p ?\U000F035C))
  (should-not (modern-tab--private-use-p ?\u2261))
  (should-not (modern-tab--encodable-p "\uEA60"))
  (should (equal (modern-tab-glyph "\uEA60" "+") "+")))

(ert-deftest modern-tab-test-a-glyph-is-judged-by-every-character ()
  "A candidate passes only where a terminal encodes all of it.
The glyphs of the tab bar are padded with the spaces that hold them
away from the text beside them.  Asking about the first character asked
about a space, which every display draws: measured on a daemon with a
terminal frame, the new button came out as the nerd glyph of its first
candidate — a box there."
  (skip-unless (not (display-graphic-p)))
  (should-not (modern-tab--encodable-p " \uEA60 "))
  (should (equal (modern-tab-glyph " \uEA60 " " + ") " + "))
  ;; and the padding alone still passes
  (should (modern-tab--encodable-p "   ")))

(defun modern-tab-test--glyph (glyphs)
  "Return the character of the first of GLYPHS that is not a space.
The candidates are padded, and it is the glyph itself that is asked
about."
  (seq-find (lambda (char) (> char ?\s)) (string-to-list (car glyphs))))

(ert-deftest modern-tab-test-both-rows-lead-with-one-family ()
  "The buttons of the two rows are drawn at one weight and one size.
Every one of them leads with a codicon — the block from EA60 to EC84 —
because a nerd glyph of another family is drawn at another weight: the
material design chevron is bold beside the codicon plus, and the
octicon cross is half its size.  The close button of the two rows is
the same glyph, with the padding each row needs."
  (dolist (glyphs (list modern-tab-bar-new-glyphs
                        modern-tab-bar-close-glyphs
                        modern-tab-bar-menu-glyphs
                        modern-tab-bar-current-glyphs
                        modern-tab-line-close-glyphs))
    (should (<= #xEA60 (modern-tab-test--glyph glyphs) #xEC84)))
  (should (= (modern-tab-test--glyph modern-tab-bar-close-glyphs)
             (modern-tab-test--glyph modern-tab-line-close-glyphs)))
  (should-not (= (modern-tab-test--glyph modern-tab-bar-close-glyphs)
                 (modern-tab-test--glyph modern-tab-bar-new-glyphs)))
  ;; A terminal takes the last candidate, and two different buttons
  ;; must not come out as the same character there.
  (should-not (equal (car (last modern-tab-bar-close-glyphs))
                     (car (last modern-tab-bar-new-glyphs))))
  (should-not (equal (car (last modern-tab-bar-menu-glyphs))
                     (car (last modern-tab-bar-current-glyphs)))))

(ert-deftest modern-tab-test-a-button-is-resolved-once-and-kept ()
  "`modern-tab--button' picks a candidate for this display and keeps it."
  (skip-unless (not (display-graphic-p)))
  (modern-tab-forget)
  ;; The nerd candidate is a private use glyph, which a terminal refuses.
  (should (equal (modern-tab--button 'a-button '("\uEA76 " "x ")) "x "))
  ;; Kept: the candidates of the second call are not looked at.
  (should (equal (modern-tab--button 'a-button '("!")) "x "))
  (modern-tab-forget)
  (should (equal (modern-tab--button 'a-button '("!")) "!")))

(ert-deftest modern-tab-test-an-icon-spec-is-a-string-or-a-plist ()
  "A string stands for itself, nil is nothing, a plist names a nerd icon."
  (should (equal (modern-tab-icon "*") "*"))
  (should (equal (modern-tab-icon nil) ""))
  ;; Without nerd-icons the plist falls back to the plain candidate.
  (skip-unless (not (fboundp 'nerd-icons-octicon)))
  (should (equal (modern-tab-icon '(:style "oct" :icon "dot_fill")) "?")))

(ert-deftest modern-tab-test-an-icon-is-answered-once-per-display ()
  "The answer is kept, and forgetting it asks again."
  (modern-tab-forget)
  (should (equal (modern-tab-icon-for "a group" "*") "*"))
  ;; The spec of the second call is ignored: the answer is the one kept.
  (should (equal (modern-tab-icon-for "a group" "!") "*"))
  (modern-tab-forget)
  (should (equal (modern-tab-icon-for "a group" "!") "!")))

(ert-deftest modern-tab-test-forgetting-an-icon-clears-the-row-drawn ()
  "A row of the tab line already drawn is kept in a window parameter.
The key it is kept under says nothing about the options of this
package, so the row would otherwise keep the glyph of the option before
the change."
  (set-window-parameter nil 'tab-line-cache 'a-row-of-the-option-before)
  (modern-tab-forget)
  (should-not (window-parameter nil 'tab-line-cache)))

(ert-deftest modern-tab-test-setting-an-option-forgets-the-icons ()
  "An option an icon depends on empties the table when it is set."
  (modern-tab-icon-for "a group" "*")
  (modern-tab-set-and-forget 'modern-tab-bar-default-icon "+")
  (should (equal (modern-tab-icon-for "a group" "!") "!"))
  (setq modern-tab-bar-default-icon '(:style "oct" :icon "dot_fill")))

;;;; The tab bar

(ert-deftest modern-tab-bar-test-a-group-takes-the-first-pattern-that-matches ()
  "The first entry whose regexp matches names the icon; case matters."
  (let ((modern-tab-bar-icons '(("HOME" . "H") ("^\\[P\\]" . "P")))
        (modern-tab-bar-default-icon "."))
    (modern-tab-forget)
    (should (equal (modern-tab-bar--group-icon "HOME") "H"))
    (should (equal (modern-tab-bar--group-icon "[P] project") "P"))
    ;; `string-match-p' honours a buffer-local `case-fold-search', and
    ;; the patterns are the reader's, not the buffer's.
    (let ((case-fold-search t))
      (should (equal (modern-tab-bar--group-icon "homelab") ".")))))

(ert-deftest modern-tab-bar-test-a-group-shows-its-bar-and-its-name ()
  "The entry of a group is the bar, then the icon and the name in a face."
  (let ((modern-tab-bar-icons '(("." . "*")))
        (tab-bar-tab-group-function (lambda (_tab) "work")))
    (modern-tab-forget)
    (let ((current (substring-no-properties
                    (modern-tab-bar-group-format nil 0 t)))
          (other (substring-no-properties
                  (modern-tab-bar-group-format nil 0 nil))))
      (should (string-suffix-p " * work " current))
      (should (string-suffix-p " * work " other))
      (should (equal (get-text-property 1 'face
                                        (modern-tab-bar-group-format nil 0 t))
                     'tab-bar-tab-group-current)))))

(ert-deftest modern-tab-bar-test-a-group-name-can-be-rewritten ()
  "`modern-tab-bar-group-name-function' says what the name reads as."
  (let ((modern-tab-bar-icons '(("." . "*")))
        (modern-tab-bar-group-name-function #'upcase)
        (tab-bar-tab-group-function (lambda (_tab) "work")))
    (modern-tab-forget)
    (should (string-suffix-p " * WORK "
                             (substring-no-properties
                              (modern-tab-bar-group-format nil 0 t))))))

(ert-deftest modern-tab-bar-test-the-close-button-reads-four-values ()
  "`tab-bar-close-button-show' says which tabs carry the button."
  (let ((modern-tab-bar-close-glyphs '("X"))
        (tab-bar-tab-hints nil)
        ;; A tab is an alist whose car says which kind it is.
        (tab '(current-tab (name . "one"))))
    (modern-tab-forget)
    (let ((tab-bar-close-button-show 'selected))
      (should (string-suffix-p "X" (substring-no-properties
                                    (modern-tab-bar-name-format tab 1)))))
    (let ((tab-bar-close-button-show 'non-selected))
      (should-not (string-suffix-p "X" (substring-no-properties
                                        (modern-tab-bar-name-format tab 1)))))
    (let ((tab-bar-close-button-show nil))
      (should-not (string-suffix-p "X" (substring-no-properties
                                        (modern-tab-bar-name-format tab 1)))))))

(ert-deftest modern-tab-bar-test-a-tab-is-as-wide-as-the-selected-one ()
  "The mark on the selected tab is two columns, and so is its absence.
Every candidate of `modern-tab-bar-current-glyphs' is two columns wide
— the last one is two spaces — so a tab that carries no mark is padded
to the same width.  With one space there the names of the tabs were a
column out of line."
  (let ((modern-tab-bar-current-glyphs '("> "))
        (tab-bar-tab-hints nil)
        (tab-bar-close-button-show nil))
    (modern-tab-forget)
    (let ((selected (substring-no-properties
                     (modern-tab-bar-name-format
                      '(current-tab (name . "a")) 1)))
          (other (substring-no-properties
                  (modern-tab-bar-name-format '(tab (name . "a")) 2))))
      (should (equal selected "> a "))
      (should (equal other "  a "))
      (should (= (string-width selected) (string-width other))))))

(ert-deftest modern-tab-bar-test-hints-show-the-number ()
  "A tab shows its index where `tab-bar-tab-hints' asks for it."
  (let ((tab-bar-close-button-show nil)
        (tab '(tab (name . "one"))))
    (let ((tab-bar-tab-hints t))
      (should (string-match-p "3 one"
                              (modern-tab-bar-name-format tab 3))))
    (let ((tab-bar-tab-hints nil))
      (should-not (string-match-p "3 one"
                                  (modern-tab-bar-name-format tab 3))))))

(ert-deftest modern-tab-bar-test-the-menu-button-stays-out-of-a-terminal ()
  "The menu button leaves a terminal's tab bar row blank, so it draws none.
Asked per redisplay, so a daemon answers it for each of its frames: the
entry stays in the format and answers nothing where it must."
  (skip-unless (not (display-graphic-p)))
  (should (memq 'modern-tab-bar--menu-bar modern-tab-bar-format))
  (should-not (modern-tab-bar--menu-bar))
  ;; and the spaces that pad it are gone with it
  (should-not (modern-tab-bar--thin-spacer))
  (should-not (modern-tab-bar--wide-spacer)))

(ert-deftest modern-tab-bar-test-the-new-button-runs-the-command-it-is-given ()
  "`modern-tab-bar-new-command' is what the button of the format runs."
  (let ((modern-tab-bar-new-command #'ignore)
        (modern-tab-bar-new-glyphs '("+")))
    (modern-tab-forget)
    (should (equal (modern-tab-bar-format-new-button)
                   '((add-tab menu-item "+" ignore :help "New"))))))

(ert-deftest modern-tab-bar-test-the-mode-gives-the-tab-bar-back ()
  "Turning the mode off gives back what the reader had, not what custom says.
Every variable the mode sets, the format included:
`custom-reevaluate-setting' was the restore before this, and it reads
the custom file — so a value set with `setq' was thrown away and a
plain `defvar' was set to nil.  The two buttons are drawn per redisplay
and no variable of the tab bar holds them."
  (let ((tab-bar-separator " | ")
        (tab-bar-auto-width nil)
        (tab-bar-new-button "MINE-NEW")
        (tab-bar-close-button "MINE-CLOSE")
        (tab-bar-format '(tab-bar-format-tabs))
        (tab-bar-tab-name-format-function #'ignore)
        (tab-bar-tab-group-format-function #'ignore))
    (let ((was (list tab-bar-separator tab-bar-auto-width
                     tab-bar-new-button tab-bar-close-button
                     tab-bar-format
                     tab-bar-tab-name-format-function
                     tab-bar-tab-group-format-function)))
      (modern-tab-bar-mode 1)
      (should (eq tab-bar-tab-name-format-function #'modern-tab-bar-name-format))
      (should (equal tab-bar-separator ""))
      ;; the buttons of the tab bar are not this mode's to set
      (should (equal tab-bar-new-button "MINE-NEW"))
      (should (equal tab-bar-close-button "MINE-CLOSE"))
      (modern-tab-bar-mode -1)
      (should (equal (list tab-bar-separator tab-bar-auto-width
                           tab-bar-new-button tab-bar-close-button
                           tab-bar-format
                           tab-bar-tab-name-format-function
                           tab-bar-tab-group-format-function)
                     was)))))

(ert-deftest modern-tab-bar-test-the-font-hook-belongs-to-the-file ()
  "Forgetting the icons on a new font is not one mode's business.
Both modes read the same table, and either of them turning off used to
take the hook away from the other."
  (should (memq #'modern-tab-forget after-setting-font-hook))
  (modern-tab-bar-mode 1)
  (modern-tab-bar-mode -1)
  (should (memq #'modern-tab-forget after-setting-font-hook)))

(ert-deftest modern-tab-bar-test-a-group-with-no-name-is-not-an-error ()
  "`tab-bar-tab-group-format-function' can be called with a nil group.
Stock Emacs does not, but the hook is public and a reader who replaces
`tab-bar-format-tabs-groups' can."
  (modern-tab-forget)
  (should (stringp (modern-tab-bar--group-icon nil)))
  (should (stringp (modern-tab-bar--group-icon ""))))

(ert-deftest modern-tab-bar-test-a-tab-wears-the-face-the-tab-bar-chose ()
  "The face comes from `tab-bar-tab-face-function', not from a name here.
Naming `tab-bar-tab' drew every tab in the selected tab's colours, and
`tab-bar-tab-inactive' never rendered at all."
  (let* ((tab-bar-close-button-show nil)
         (calls 0)
         (tab-bar-tab-face-function
          (lambda (_tab) (setq calls (1+ calls)) 'my-face)))
    (should (equal (get-text-property
                    0 'face (modern-tab-bar-name-format '(tab (name . "x")) 1))
                   '(:inherit my-face :weight normal)))
    (should (= calls 1))))

(ert-deftest modern-tab-test-the-icon-table-tells-the-rows-apart ()
  "A tab group and a buffer of the same name do not share an icon.
One table serves both rows, so the key says which row asked."
  (modern-tab-forget)
  (should (equal (modern-tab-icon-for (cons 'group "same") "G") "G"))
  (should (equal (modern-tab-icon-for (cons 'buffer "same") "B") "B")))

;;;; The tab line

(ert-deftest modern-tab-line-test-a-tab-shows-its-name ()
  "The tab of a buffer is the bar, then the icon and the name."
  (let ((modern-tab-line-icon-function nil))
    (with-temp-buffer
      (rename-buffer "one.py" t)
      (should (string-suffix-p
               " one.py "
               (substring-no-properties
                (modern-tab-line-tab-name (current-buffer))))))))

(ert-deftest modern-tab-line-test-an-icon-goes-between-the-two ()
  "An icon function that answers puts its glyph before the name."
  (let ((modern-tab-line-icon-function (lambda (_buffer) "#")))
    (with-temp-buffer
      (rename-buffer "one.py" t)
      (should (string-suffix-p
               " # one.py "
               (substring-no-properties
                (modern-tab-line-tab-name (current-buffer)))))))
  ;; And one that answers with nothing leaves no gap of its own.
  (let ((modern-tab-line-icon-function (lambda (_buffer) "")))
    (with-temp-buffer
      (rename-buffer "one.py" t)
      (should (string-suffix-p
               " one.py "
               (substring-no-properties
                (modern-tab-line-tab-name (current-buffer))))))))

(ert-deftest modern-tab-line-test-a-tab-is-a-buffer-or-an-alist ()
  "`modern-tab-line--buffer' answers for both shapes a tab comes in."
  (with-temp-buffer
    (should (eq (modern-tab-line--buffer (current-buffer)) (current-buffer)))
    (should (eq (modern-tab-line--buffer `((buffer . ,(current-buffer))))
                (current-buffer))))
  ;; `tab-line-tabs-function' is public, and a tab of a reader's own
  ;; function need stand for no buffer at all.
  (should-not (modern-tab-line--buffer 'something-else))
  (should-not (modern-tab-line--buffer '((name . "no buffer here")))))

(ert-deftest modern-tab-line-test-the-close-button-is-drawn-per-display ()
  "The button is a function of the frame, not a string settled at enable.
A daemon enables its modes with no frame at all, so a button settled
then carried a terminal's answer onto every graphic frame after it."
  (let ((modern-tab-line-close-glyphs '("Z")))
    (modern-tab-forget)
    (let ((button (modern-tab-line-close-button)))
      (should (equal (substring-no-properties button) "Z"))
      (should (eq (get-text-property 0 'keymap button) tab-line-tab-close-map))
      (should (eq (get-text-property 0 'mouse-face button)
                  'tab-line-close-highlight)))))

(ert-deftest modern-tab-line-test-the-row-draws-the-button-of-its-frame ()
  "`modern-tab-line-tab-format' binds the button the row formats with."
  (let ((modern-tab-line-close-glyphs '("Z"))
        (modern-tab-line-icon-function nil)
        (modern-tab-line-active-indicator-width 0)
        (tab-line-close-button-show 'selected)
        (tab-line-tab-name-function #'modern-tab-line-tab-name)
        (tab-line-close-button "SETTLED"))
    (modern-tab-forget)
    (with-temp-buffer
      (set-window-buffer nil (current-buffer))
      (let ((tabs (list (current-buffer))))
        (should (string-suffix-p
                 "Z" (substring-no-properties
                      (modern-tab-line-tab-format (car tabs) tabs)))))
      ;; and the binding is undone, so nothing of the reader's is lost
      (should (equal tab-line-close-button "SETTLED")))))

(ert-deftest modern-tab-line-test-closing-a-tab-kills-the-buffer ()
  "A buffer no other window shows is killed when its tab closes."
  (let ((buffer (generate-new-buffer "modern-tab-line-test")))
    (should (buffer-live-p buffer))
    (modern-tab-line-close-tab buffer)
    (should-not (buffer-live-p buffer))))

(ert-deftest modern-tab-line-test-the-mode-gives-the-tab-line-back ()
  "Turning the mode off gives back every variable it set.
`tab-line-close-button' is not one of them any more: the row binds it
per redisplay, so the reader's own button is left where it stood."
  (let ((tab-line-separator " | ")
        (tab-line-tab-name-function #'ignore)
        (tab-line-close-tab-function #'ignore)
        (tab-line-new-button-show t)
        (tab-line-close-button-show t)
        (tab-line-close-button "MINE"))
    (let ((was (list tab-line-separator tab-line-tab-name-function
                     tab-line-close-tab-function tab-line-new-button-show
                     tab-line-close-button-show tab-line-close-button)))
      (modern-tab-line-mode 1)
      (should (eq tab-line-tab-name-function #'modern-tab-line-tab-name))
      (should (equal tab-line-close-button "MINE"))
      (modern-tab-line-mode -1)
      (should (equal (list tab-line-separator tab-line-tab-name-function
                           tab-line-close-tab-function
                           tab-line-new-button-show
                           tab-line-close-button-show tab-line-close-button)
                     was)))))

(ert-deftest modern-tab-line-test-the-mode-watches-the-windows ()
  "The mode asks about a row when a window changes, not when a buffer does.
`buffer-list-update-hook' was here before: it runs on every
`get-buffer-create', `set-buffer' and `kill-buffer' — about twice per
buffer operation — and walked the buffer lists of a window each time.
What changes a window's row of tabs is a window showing another buffer,
the windows themselves changing, and a buffer being killed."
  (modern-tab-line-mode 1)
  (should (memq #'modern-tab-line-update-frame window-buffer-change-functions))
  (should (memq #'modern-tab-line-update-frame
                window-configuration-change-hook))
  (should (memq #'modern-tab-line--buffer-killed kill-buffer-hook))
  (should-not (memq #'modern-tab-line-update-window buffer-list-update-hook))
  (modern-tab-line-mode -1)
  (should-not (memq #'modern-tab-line-update-frame
                    window-buffer-change-functions))
  (should-not (memq #'modern-tab-line-update-frame
                    window-configuration-change-hook))
  (should-not (memq #'modern-tab-line--buffer-killed kill-buffer-hook)))

(ert-deftest modern-tab-line-test-another-buffer-in-a-window-shows-the-row ()
  "A window that shows a second buffer gets its row back."
  (let ((modern-tab-line-auto-hide t)
        (one (generate-new-buffer "modern-tab-line-test-one"))
        (two (generate-new-buffer "modern-tab-line-test-two")))
    (set-window-parameter nil 'tab-line-format nil)
    (set-window-buffer nil one)
    (set-window-prev-buffers nil nil)
    (set-window-next-buffers nil nil)
    (modern-tab-line-update-frame)
    (should (eq (window-parameter nil 'tab-line-format) 'none))
    ;; the window shows another buffer, so the one before it is a tab
    (set-window-buffer nil two)
    (modern-tab-line-update-frame)
    (should-not (window-parameter nil 'tab-line-format))
    (kill-buffer one)
    (kill-buffer two)
    (set-window-parameter nil 'tab-line-format nil)))

(ert-deftest modern-tab-line-test-killing-a-tab-hides-a-row-of-one ()
  "A killed buffer leaves the buffer lists of a window with no window change.
`kill-buffer-hook' is the only word of it, and it runs before the
buffer goes: the tab of the buffer that is going is discounted."
  (let ((modern-tab-line-auto-hide t)
        (one (generate-new-buffer "modern-tab-line-test-one"))
        (two (generate-new-buffer "modern-tab-line-test-two")))
    (set-window-parameter nil 'tab-line-format nil)
    (set-window-buffer nil one)
    (set-window-prev-buffers nil nil)
    (set-window-next-buffers nil nil)
    (set-window-buffer nil two)
    (should (memq one (mapcar #'car (window-prev-buffers))))
    ;; the hook runs while the buffer is still there, so a count that
    ;; keeps it would leave the row of a single tab showing
    (let ((modern-tab-line--dying one))
      (should-not (modern-tab-line--several-p)))
    (should (modern-tab-line--several-p))
    (modern-tab-line--buffer-killed)
    (should-not (window-parameter nil 'tab-line-format))
    (with-current-buffer one (modern-tab-line--buffer-killed))
    (should (eq (window-parameter nil 'tab-line-format) 'none))
    (kill-buffer one)
    (kill-buffer two)
    (set-window-parameter nil 'tab-line-format nil)))

(ert-deftest modern-tab-line-test-a-new-window-is-asked-about-too ()
  "A window that splitting made is asked about its own row."
  (skip-unless (> (window-body-height) 6))
  (let ((modern-tab-line-auto-hide t)
        (buffer (generate-new-buffer "modern-tab-line-test-split")))
    (set-window-parameter nil 'tab-line-format nil)
    (set-window-buffer nil buffer)
    (set-window-prev-buffers nil nil)
    (set-window-next-buffers nil nil)
    (let ((other (split-window)))
      (modern-tab-line-update-frame)
      (should (eq (window-parameter other 'tab-line-format) 'none))
      (delete-window other))
    (modern-tab-line-update-frame)
    (should (eq (window-parameter nil 'tab-line-format) 'none))
    (kill-buffer buffer)
    (set-window-parameter nil 'tab-line-format nil)))

(ert-deftest modern-tab-line-test-the-row-is-the-readers ()
  "The mode neither enables nor disables `global-tab-line-mode'.
The row is the reader's, the way the tab bar is with
`modern-tab-bar-mode': the mode only dresses what is shown."
  (should-not global-tab-line-mode)
  (modern-tab-line-mode 1)
  (should-not global-tab-line-mode)
  (global-tab-line-mode 1)
  (modern-tab-line-mode -1)
  (should global-tab-line-mode)
  (global-tab-line-mode -1))

(ert-deftest modern-tab-line-test-a-parameter-of-somebody-else-stays ()
  "Only the rows this package hid come back when the mode goes."
  (set-window-parameter nil 'tab-line-format 'mine)
  (modern-tab-line-mode 1)
  (modern-tab-line-mode -1)
  (should (eq (window-parameter nil 'tab-line-format) 'mine))
  (set-window-parameter nil 'tab-line-format nil))

(ert-deftest modern-tab-line-test-hiding-can-be-turned-off ()
  "With `modern-tab-line-auto-hide' nil no window parameter is touched."
  (let ((modern-tab-line-auto-hide nil))
    (set-window-parameter nil 'tab-line-format nil)
    (set-window-parameter nil 'modern-tab-line-hide nil)
    (modern-tab-line-update-window)
    (should-not (window-parameter nil 'tab-line-format)))
  ;; And with it on, a window showing one buffer hides the row.
  (let ((modern-tab-line-auto-hide t))
    (modern-tab-line-update-window)
    (should (eq (window-parameter nil 'tab-line-format) 'none))
    (set-window-parameter nil 'tab-line-format nil)
    (set-window-parameter nil 'modern-tab-line-hide nil)))

(ert-deftest modern-tab-line-test-hiding-takes-effect-in-both-ways ()
  "Setting the option acts at once, whichever way it is set.
Off left every row this package had hidden hidden for good, and on
left every row of a single tab showing until something changed a
window.  The `:set' function answers for both directions."
  (let ((one (generate-new-buffer "modern-tab-line-test-one")))
    (unwind-protect
        (progn
          (set-window-buffer nil one)
          (set-window-prev-buffers nil nil)
          (set-window-next-buffers nil nil)
          (set-window-parameter nil 'tab-line-format nil)
          (set-window-parameter nil 'modern-tab-line-hide nil)
          (customize-set-variable 'modern-tab-line-auto-hide t)
          (should (eq (window-parameter nil 'tab-line-format) 'none))
          (customize-set-variable 'modern-tab-line-auto-hide nil)
          (should-not (window-parameter nil 'tab-line-format))
          ;; and on again, which is the direction that did nothing
          (customize-set-variable 'modern-tab-line-auto-hide t)
          (should (eq (window-parameter nil 'tab-line-format) 'none)))
      (customize-set-variable 'modern-tab-line-auto-hide t)
      (set-window-parameter nil 'tab-line-format nil)
      (set-window-parameter nil 'modern-tab-line-hide nil)
      (kill-buffer one))))

(ert-deftest modern-tab-line-test-a-hiding-of-another-stays ()
  "A `none' this package did not set is not undone, and not re-decided.
`auto-side-windows' hides the side panels of a frame with a `none' of
its own; the row must not come back on them, at a decision, at the
teardown of the mode, or anywhere."
  (set-window-parameter nil 'modern-tab-line-hide nil)
  (set-window-parameter nil 'tab-line-format 'none)
  (let ((modern-tab-line-auto-hide t))
    (modern-tab-line-update-window)
    (should (eq (window-parameter nil 'tab-line-format) 'none))
    (modern-tab-line-mode 1)
    (modern-tab-line-mode -1)
    (should (eq (window-parameter nil 'tab-line-format) 'none)))
  (set-window-parameter nil 'tab-line-format nil))

(defvar modern-tab-test--borrowed-var 'reader
  "A variable for the borrow tests to keep and give back.")

(ert-deftest modern-tab-test-a-second-enable-borrows-nothing ()
  "The values a mode borrows are the ones it found the first time.
`define-minor-mode' runs its body on every call and a nil argument
means enable, so a mode enabled twice would record the values it set
itself and give those back instead of the reader's."
  (let ((modern-tab--borrowed nil)
        (modern-tab-test--borrowed-var 'reader))
    (should (modern-tab--borrow 'modern-tab-test-mode
                                'modern-tab-test--borrowed-var))
    (setq modern-tab-test--borrowed-var 'mine)
    (should-not (modern-tab--borrow 'modern-tab-test-mode
                                    'modern-tab-test--borrowed-var))
    (should (modern-tab--give-back 'modern-tab-test-mode))
    (should (eq modern-tab-test--borrowed-var 'reader))
    ;; and a mode that borrowed nothing gives nothing back: its
    ;; teardown must not switch off what the package never touched
    (should-not (modern-tab--give-back 'modern-tab-test-mode))))

(ert-deftest modern-tab-line-test-the-mode-survives-its-own-hook ()
  "A reader may turn this mode on from `tab-line-mode-hook'.
The setup once re-enabled `global-tab-line-mode' there, and the pair
recursed until `max-lisp-eval-depth' gave out — a whole configuration
failed to start.  The mode leaves the row alone now."
  (let ((max-lisp-eval-depth 200)
        (hook (lambda () (modern-tab-line-mode 1))))
    (add-hook 'tab-line-mode-hook hook)
    (unwind-protect
        (progn
          (modern-tab-line-mode 1)
          (with-temp-buffer (tab-line-mode 1))
          (should modern-tab-line-mode))
      (remove-hook 'tab-line-mode-hook hook)
      (modern-tab-line-mode -1))))

(ert-deftest modern-tab-line-test-the-tabs-are-the-ones-the-row-shows ()
  "`tab-line-tabs-function' says what the row shows, and a reader may set it."
  (let ((tab-line-tabs-function (lambda () '(a b))))
    (should (modern-tab-line--several-p)))
  (let ((tab-line-tabs-function (lambda () '(a))))
    (should-not (modern-tab-line--several-p))))

(provide 'modern-tab-test)
;;; modern-tab-test.el ends here
