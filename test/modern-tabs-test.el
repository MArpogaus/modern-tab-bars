;;; modern-tabs-test.el --- Tests for modern-tabs -*- lexical-binding: t; -*-

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
(require 'modern-tabs)
(require 'modern-tabs-bar)
(require 'modern-tabs-line)

;;;; The bar

(ert-deftest modern-tabs-test-a-bar-of-no-width-is-nothing ()
  "A width of nil or zero draws no bar."
  (should (equal (modern-tabs-indicator 20 nil "red") ""))
  (should (equal (modern-tabs-indicator 20 0 "red") "")))

(ert-deftest modern-tabs-test-a-terminal-bar-is-a-line ()
  "Without a graphic display the bar is one column of a vertical line."
  (skip-unless (not (display-graphic-p)))
  (let ((bar (modern-tabs-indicator 20 3 "red")))
    (should (equal (substring-no-properties bar) "|"))
    (should (equal (get-text-property 0 'face bar)
                   '(:foreground "red" :background "red")))))

(ert-deftest modern-tabs-test-a-bar-without-a-colour-wears-no-face ()
  "A face attribute of nil is an error the display logs, so there is none."
  (skip-unless (not (display-graphic-p)))
  (should-not (get-text-property 0 'face (modern-tabs-indicator 20 3 nil))))

(ert-deftest modern-tabs-test-a-colour-comes-from-a-name-or-a-face ()
  "A colour names itself; a face gives its foreground."
  (should (equal (modern-tabs--color "#ff0000") "#ff0000"))
  (should (equal (modern-tabs--color 'default)
                 (face-foreground 'default nil 'default)))
  (should-not (modern-tabs--color nil)))

(ert-deftest modern-tabs-test-a-tab-reads-the-option-of-its-state ()
  "Each state has its own width and its own colour.
The selected tab of the tab line takes a bar; the others take none,
which is what a width of zero asks for.  The bar comes from
`modern-tabs-line-tab-format', which puts it in front of the name the
row formats: the face of a terminal bar would not survive the
`propertize' that formatting does."
  (skip-unless (not (display-graphic-p)))
  (let ((modern-tabs-line-active-indicator-width 3)
        (modern-tabs-line-inactive-indicator-width 0)
        (modern-tabs-line-active-indicator-color "red")
        (modern-tabs-line-icon-function nil)
        (tab-line-tab-name-function #'modern-tabs-line-tab-name))
    (with-temp-buffer
      (set-window-buffer nil (current-buffer))
      (let* ((tabs (list (current-buffer) (get-buffer-create "*other*")))
             (selected (modern-tabs-line-tab-format (car tabs) tabs))
             (other (modern-tabs-line-tab-format (cadr tabs) tabs)))
        (should (equal (get-text-property 0 'face selected)
                       '(:foreground "red" :background "red")))
        (should (string-prefix-p "|" (substring-no-properties selected)))
        (should (string-prefix-p " " (substring-no-properties other)))))))

;;;; Glyphs and icons

(ert-deftest modern-tabs-test-a-glyph-falls-back-to-the-last ()
  "The last candidate answers where the frame can draw none of them."
  (should (equal (modern-tabs-glyph "" nil "x") "x"))
  ;; A plain character a terminal can draw wins over the ones after it.
  (should (equal (modern-tabs-glyph "a" "b") "a")))

(ert-deftest modern-tabs-test-a-private-use-glyph-is-refused-by-a-terminal ()
  "A terminal can encode a nerd glyph and has no font that draws it.
`char-displayable-p' answers for the coding system, so a UTF-8 terminal
says yes to a character it shows as a box."
  (skip-unless (not (display-graphic-p)))
  (should (modern-tabs--private-use-p ?\uE000))
  (should (modern-tabs--private-use-p ?\uF8FF))
  (should (modern-tabs--private-use-p ?\U000F035C))
  (should-not (modern-tabs--private-use-p ?\u2261))
  (should-not (modern-tabs--encodable-p "\uEA60"))
  (should (equal (modern-tabs-glyph "\uEA60" "+") "+")))

(ert-deftest modern-tabs-test-a-glyph-is-judged-by-every-character ()
  "A candidate passes only where a terminal encodes all of it.
The glyphs of the tab bar are padded with the spaces that hold them
away from the text beside them.  Asking about the first character asked
about a space, which every display draws: measured on a daemon with a
terminal frame, the new button came out as the nerd glyph of its first
candidate — a box there."
  (skip-unless (not (display-graphic-p)))
  (should-not (modern-tabs--encodable-p " \uEA60 "))
  (should (equal (modern-tabs-glyph " \uEA60 " " + ") " + "))
  ;; and the padding alone still passes
  (should (modern-tabs--encodable-p "   ")))

(ert-deftest modern-tabs-test-an-icon-spec-is-a-string-or-a-plist ()
  "A string stands for itself, nil is nothing, a plist names a nerd icon."
  (should (equal (modern-tabs-icon "*") "*"))
  (should (equal (modern-tabs-icon nil) ""))
  ;; Without nerd-icons the plist falls back to the plain candidate.
  (skip-unless (not (fboundp 'nerd-icons-octicon)))
  (should (equal (modern-tabs-icon '(:style "oct" :icon "dot_fill")) "?")))

(ert-deftest modern-tabs-test-an-icon-is-answered-once-per-display ()
  "The answer is kept, and forgetting it asks again."
  (modern-tabs-forget)
  (should (equal (modern-tabs-icon-for "a group" "*") "*"))
  ;; The spec of the second call is ignored: the answer is the one kept.
  (should (equal (modern-tabs-icon-for "a group" "!") "*"))
  (modern-tabs-forget)
  (should (equal (modern-tabs-icon-for "a group" "!") "!")))

(ert-deftest modern-tabs-test-forgetting-an-icon-clears-the-row-drawn ()
  "A row of the tab line already drawn is kept in a window parameter.
The key it is kept under says nothing about the options of this
package, so the row would otherwise keep the glyph of the option before
the change."
  (set-window-parameter nil 'tab-line-cache 'a-row-of-the-option-before)
  (modern-tabs-forget)
  (should-not (window-parameter nil 'tab-line-cache)))

(ert-deftest modern-tabs-test-setting-an-option-forgets-the-icons ()
  "An option an icon depends on empties the table when it is set."
  (modern-tabs-icon-for "a group" "*")
  (modern-tabs-set-and-forget 'modern-tabs-bar-default-icon "+")
  (should (equal (modern-tabs-icon-for "a group" "!") "!"))
  (setq modern-tabs-bar-default-icon '(:style "oct" :icon "dot_fill")))

;;;; The tab bar

(ert-deftest modern-tabs-bar-test-a-group-takes-the-first-pattern-that-matches ()
  "The first entry whose regexp matches names the icon; case matters."
  (let ((modern-tabs-bar-icons '(("HOME" . "H") ("^\\[P\\]" . "P")))
        (modern-tabs-bar-default-icon "."))
    (modern-tabs-forget)
    (should (equal (modern-tabs-bar--group-icon "HOME") "H"))
    (should (equal (modern-tabs-bar--group-icon "[P] project") "P"))
    ;; `string-match-p' honours a buffer-local `case-fold-search', and
    ;; the patterns are the reader's, not the buffer's.
    (let ((case-fold-search t))
      (should (equal (modern-tabs-bar--group-icon "homelab") ".")))))

(ert-deftest modern-tabs-bar-test-a-group-shows-its-bar-and-its-name ()
  "The entry of a group is the bar, then the icon and the name in a face."
  (let ((modern-tabs-bar-icons '(("." . "*")))
        (tab-bar-tab-group-function (lambda (_tab) "work")))
    (modern-tabs-forget)
    (let ((current (substring-no-properties
                    (modern-tabs-bar-group-format nil 0 t)))
          (other (substring-no-properties
                  (modern-tabs-bar-group-format nil 0 nil))))
      (should (string-suffix-p " * work " current))
      (should (string-suffix-p " * work " other))
      (should (equal (get-text-property 1 'face
                                        (modern-tabs-bar-group-format nil 0 t))
                     'tab-bar-tab-group-current)))))

(ert-deftest modern-tabs-bar-test-a-group-name-can-be-rewritten ()
  "`modern-tabs-bar-group-name-function' says what the name reads as."
  (let ((modern-tabs-bar-icons '(("." . "*")))
        (modern-tabs-bar-group-name-function #'upcase)
        (tab-bar-tab-group-function (lambda (_tab) "work")))
    (modern-tabs-forget)
    (should (string-suffix-p " * WORK "
                             (substring-no-properties
                              (modern-tabs-bar-group-format nil 0 t))))))

(ert-deftest modern-tabs-bar-test-the-close-button-reads-four-values ()
  "`tab-bar-close-button-show' says which tabs carry the button."
  (let ((modern-tabs-bar-close-glyphs '("X"))
        (tab-bar-tab-hints nil)
        ;; A tab is an alist whose car says which kind it is.
        (tab '(current-tab (name . "one"))))
    (modern-tabs-forget)
    (let ((tab-bar-close-button-show 'selected))
      (should (string-suffix-p "X" (substring-no-properties
                                    (modern-tabs-bar-name-format tab 1)))))
    (let ((tab-bar-close-button-show 'non-selected))
      (should-not (string-suffix-p "X" (substring-no-properties
                                        (modern-tabs-bar-name-format tab 1)))))
    (let ((tab-bar-close-button-show nil))
      (should-not (string-suffix-p "X" (substring-no-properties
                                        (modern-tabs-bar-name-format tab 1)))))))

(ert-deftest modern-tabs-bar-test-hints-show-the-number ()
  "A tab shows its index where `tab-bar-tab-hints' asks for it."
  (let ((tab-bar-close-button-show nil)
        (tab '(tab (name . "one"))))
    (let ((tab-bar-tab-hints t))
      (should (string-match-p "3 one"
                              (modern-tabs-bar-name-format tab 3))))
    (let ((tab-bar-tab-hints nil))
      (should-not (string-match-p "3 one"
                                  (modern-tabs-bar-name-format tab 3))))))

(ert-deftest modern-tabs-bar-test-the-menu-button-stays-out-of-a-terminal ()
  "The menu button leaves a terminal's tab bar row blank, so it draws none.
Asked per redisplay, so a daemon answers it for each of its frames: the
entry stays in the format and answers nothing where it must."
  (skip-unless (not (display-graphic-p)))
  (should (memq 'modern-tabs-bar--menu-bar modern-tabs-bar-format))
  (should-not (modern-tabs-bar--menu-bar))
  ;; and the spaces that pad it are gone with it
  (should-not (modern-tabs-bar--thin-spacer))
  (should-not (modern-tabs-bar--wide-spacer)))

(ert-deftest modern-tabs-bar-test-the-new-button-runs-the-command-it-is-given ()
  "`modern-tabs-bar-new-command' is what the button of the format runs."
  (let ((modern-tabs-bar-new-command #'ignore)
        (modern-tabs-bar-new-glyphs '("+")))
    (modern-tabs-forget)
    (should (equal (modern-tabs-bar-format-new-button)
                   '((add-tab menu-item "+" ignore :help "New"))))))

(ert-deftest modern-tabs-bar-test-the-mode-gives-the-tab-bar-back ()
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
      (modern-tabs-bar-mode 1)
      (should (eq tab-bar-tab-name-format-function #'modern-tabs-bar-name-format))
      (should (equal tab-bar-separator ""))
      ;; the buttons of the tab bar are not this mode's to set
      (should (equal tab-bar-new-button "MINE-NEW"))
      (should (equal tab-bar-close-button "MINE-CLOSE"))
      (modern-tabs-bar-mode -1)
      (should (equal (list tab-bar-separator tab-bar-auto-width
                           tab-bar-new-button tab-bar-close-button
                           tab-bar-format
                           tab-bar-tab-name-format-function
                           tab-bar-tab-group-format-function)
                     was)))))

(ert-deftest modern-tabs-bar-test-the-font-hook-belongs-to-the-file ()
  "Forgetting the icons on a new font is not one mode's business.
Both modes read the same table, and either of them turning off used to
take the hook away from the other."
  (should (memq #'modern-tabs-forget after-setting-font-hook))
  (modern-tabs-bar-mode 1)
  (modern-tabs-bar-mode -1)
  (should (memq #'modern-tabs-forget after-setting-font-hook)))

(ert-deftest modern-tabs-bar-test-a-group-with-no-name-is-not-an-error ()
  "`tab-bar-tab-group-format-function' can be called with a nil group.
Stock Emacs does not, but the hook is public and a reader who replaces
`tab-bar-format-tabs-groups' can."
  (modern-tabs-forget)
  (should (stringp (modern-tabs-bar--group-icon nil)))
  (should (stringp (modern-tabs-bar--group-icon ""))))

(ert-deftest modern-tabs-bar-test-a-tab-wears-the-face-the-tab-bar-chose ()
  "The face comes from `tab-bar-tab-face-function', not from a name here.
Naming `tab-bar-tab' drew every tab in the selected tab's colours, and
`tab-bar-tab-inactive' never rendered at all."
  (let* ((tab-bar-close-button-show nil)
         (calls 0)
         (tab-bar-tab-face-function
          (lambda (_tab) (setq calls (1+ calls)) 'my-face)))
    (should (equal (get-text-property
                    0 'face (modern-tabs-bar-name-format '(tab (name . "x")) 1))
                   '(:inherit my-face :weight normal)))
    (should (= calls 1))))

(ert-deftest modern-tabs-test-the-icon-table-tells-the-rows-apart ()
  "A tab group and a buffer of the same name do not share an icon.
One table serves both rows, so the key says which row asked."
  (modern-tabs-forget)
  (should (equal (modern-tabs-icon-for (cons 'group "same") "G") "G"))
  (should (equal (modern-tabs-icon-for (cons 'buffer "same") "B") "B")))

;;;; The tab line

(ert-deftest modern-tabs-line-test-a-tab-shows-its-name ()
  "The tab of a buffer is the bar, then the icon and the name."
  (let ((modern-tabs-line-icon-function nil))
    (with-temp-buffer
      (rename-buffer "one.py" t)
      (should (string-suffix-p
               " one.py "
               (substring-no-properties
                (modern-tabs-line-tab-name (current-buffer))))))))

(ert-deftest modern-tabs-line-test-an-icon-goes-between-the-two ()
  "An icon function that answers puts its glyph before the name."
  (let ((modern-tabs-line-icon-function (lambda (_buffer) "#")))
    (with-temp-buffer
      (rename-buffer "one.py" t)
      (should (string-suffix-p
               " # one.py "
               (substring-no-properties
                (modern-tabs-line-tab-name (current-buffer)))))))
  ;; And one that answers with nothing leaves no gap of its own.
  (let ((modern-tabs-line-icon-function (lambda (_buffer) "")))
    (with-temp-buffer
      (rename-buffer "one.py" t)
      (should (string-suffix-p
               " one.py "
               (substring-no-properties
                (modern-tabs-line-tab-name (current-buffer))))))))

(ert-deftest modern-tabs-line-test-a-tab-is-a-buffer-or-an-alist ()
  "`modern-tabs-line--buffer' answers for both shapes a tab comes in."
  (with-temp-buffer
    (should (eq (modern-tabs-line--buffer (current-buffer)) (current-buffer)))
    (should (eq (modern-tabs-line--buffer `((buffer . ,(current-buffer))))
                (current-buffer))))
  ;; `tab-line-tabs-function' is public, and a tab of a reader's own
  ;; function need stand for no buffer at all.
  (should-not (modern-tabs-line--buffer 'something-else))
  (should-not (modern-tabs-line--buffer '((name . "no buffer here")))))

(ert-deftest modern-tabs-line-test-the-close-button-is-drawn-per-display ()
  "The button is a function of the frame, not a string settled at enable.
A daemon enables its modes with no frame at all, so a button settled
then carried a terminal's answer onto every graphic frame after it."
  (let ((modern-tabs-line-close-glyphs '("Z")))
    (modern-tabs-forget)
    (let ((button (modern-tabs-line-close-button)))
      (should (equal (substring-no-properties button) "Z"))
      (should (eq (get-text-property 0 'keymap button) tab-line-tab-close-map))
      (should (eq (get-text-property 0 'mouse-face button)
                  'tab-line-close-highlight)))))

(ert-deftest modern-tabs-line-test-the-row-draws-the-button-of-its-frame ()
  "`modern-tabs-line-tab-format' binds the button the row formats with."
  (let ((modern-tabs-line-close-glyphs '("Z"))
        (modern-tabs-line-icon-function nil)
        (modern-tabs-line-active-indicator-width 0)
        (tab-line-close-button-show 'selected)
        (tab-line-tab-name-function #'modern-tabs-line-tab-name)
        (tab-line-close-button "SETTLED"))
    (modern-tabs-forget)
    (with-temp-buffer
      (set-window-buffer nil (current-buffer))
      (let ((tabs (list (current-buffer))))
        (should (string-suffix-p
                 "Z" (substring-no-properties
                      (modern-tabs-line-tab-format (car tabs) tabs)))))
      ;; and the binding is undone, so nothing of the reader's is lost
      (should (equal tab-line-close-button "SETTLED")))))

(ert-deftest modern-tabs-line-test-closing-a-tab-kills-the-buffer ()
  "A buffer no other window shows is killed when its tab closes."
  (let ((buffer (generate-new-buffer "modern-tabs-line-test")))
    (should (buffer-live-p buffer))
    (modern-tabs-line-close-tab buffer)
    (should-not (buffer-live-p buffer))))

(ert-deftest modern-tabs-line-test-the-mode-gives-the-tab-line-back ()
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
      (modern-tabs-line-mode 1)
      (should (eq tab-line-tab-name-function #'modern-tabs-line-tab-name))
      (should (equal tab-line-close-button "MINE"))
      (modern-tabs-line-mode -1)
      (should (equal (list tab-line-separator tab-line-tab-name-function
                           tab-line-close-tab-function
                           tab-line-new-button-show
                           tab-line-close-button-show tab-line-close-button)
                     was)))))

(ert-deftest modern-tabs-line-test-the-mode-watches-the-windows ()
  "The mode asks about a row when a window changes, not when a buffer does.
`buffer-list-update-hook' was here before: it runs on every
`get-buffer-create', `set-buffer' and `kill-buffer' — about twice per
buffer operation — and walked the buffer lists of a window each time.
What changes a window's row of tabs is a window showing another buffer,
the windows themselves changing, and a buffer being killed."
  (modern-tabs-line-mode 1)
  (should (memq #'modern-tabs-line-update-frame window-buffer-change-functions))
  (should (memq #'modern-tabs-line-update-frame
                window-configuration-change-hook))
  (should (memq #'modern-tabs-line--buffer-killed kill-buffer-hook))
  (should-not (memq #'modern-tabs-line-update-window buffer-list-update-hook))
  (modern-tabs-line-mode -1)
  (should-not (memq #'modern-tabs-line-update-frame
                    window-buffer-change-functions))
  (should-not (memq #'modern-tabs-line-update-frame
                    window-configuration-change-hook))
  (should-not (memq #'modern-tabs-line--buffer-killed kill-buffer-hook)))

(ert-deftest modern-tabs-line-test-another-buffer-in-a-window-shows-the-row ()
  "A window that shows a second buffer gets its row back."
  (let ((modern-tabs-line-auto-hide t)
        (one (generate-new-buffer "modern-tabs-line-test-one"))
        (two (generate-new-buffer "modern-tabs-line-test-two")))
    (set-window-parameter nil 'tab-line-format nil)
    (set-window-buffer nil one)
    (set-window-prev-buffers nil nil)
    (set-window-next-buffers nil nil)
    (modern-tabs-line-update-frame)
    (should (eq (window-parameter nil 'tab-line-format) 'none))
    ;; the window shows another buffer, so the one before it is a tab
    (set-window-buffer nil two)
    (modern-tabs-line-update-frame)
    (should-not (window-parameter nil 'tab-line-format))
    (kill-buffer one)
    (kill-buffer two)
    (set-window-parameter nil 'tab-line-format nil)))

(ert-deftest modern-tabs-line-test-killing-a-tab-hides-a-row-of-one ()
  "A killed buffer leaves the buffer lists of a window with no window change.
`kill-buffer-hook' is the only word of it, and it runs before the
buffer goes: the tab of the buffer that is going is discounted."
  (let ((modern-tabs-line-auto-hide t)
        (one (generate-new-buffer "modern-tabs-line-test-one"))
        (two (generate-new-buffer "modern-tabs-line-test-two")))
    (set-window-parameter nil 'tab-line-format nil)
    (set-window-buffer nil one)
    (set-window-prev-buffers nil nil)
    (set-window-next-buffers nil nil)
    (set-window-buffer nil two)
    (should (memq one (mapcar #'car (window-prev-buffers))))
    ;; the hook runs while the buffer is still there, so a count that
    ;; keeps it would leave the row of a single tab showing
    (let ((modern-tabs-line--dying one))
      (should-not (modern-tabs-line--several-p)))
    (should (modern-tabs-line--several-p))
    (modern-tabs-line--buffer-killed)
    (should-not (window-parameter nil 'tab-line-format))
    (with-current-buffer one (modern-tabs-line--buffer-killed))
    (should (eq (window-parameter nil 'tab-line-format) 'none))
    (kill-buffer one)
    (kill-buffer two)
    (set-window-parameter nil 'tab-line-format nil)))

(ert-deftest modern-tabs-line-test-a-new-window-is-asked-about-too ()
  "A window that splitting made is asked about its own row."
  (skip-unless (> (window-body-height) 6))
  (let ((modern-tabs-line-auto-hide t)
        (buffer (generate-new-buffer "modern-tabs-line-test-split")))
    (set-window-parameter nil 'tab-line-format nil)
    (set-window-buffer nil buffer)
    (set-window-prev-buffers nil nil)
    (set-window-next-buffers nil nil)
    (let ((other (split-window)))
      (modern-tabs-line-update-frame)
      (should (eq (window-parameter other 'tab-line-format) 'none))
      (delete-window other))
    (modern-tabs-line-update-frame)
    (should (eq (window-parameter nil 'tab-line-format) 'none))
    (kill-buffer buffer)
    (set-window-parameter nil 'tab-line-format nil)))

(ert-deftest modern-tabs-line-test-the-row-is-the-readers ()
  "The mode neither enables nor disables `global-tab-line-mode'.
The row is the reader's, the way the tab bar is with
`modern-tabs-bar-mode': the mode only dresses what is shown."
  (should-not global-tab-line-mode)
  (modern-tabs-line-mode 1)
  (should-not global-tab-line-mode)
  (global-tab-line-mode 1)
  (modern-tabs-line-mode -1)
  (should global-tab-line-mode)
  (global-tab-line-mode -1))

(ert-deftest modern-tabs-line-test-a-parameter-of-somebody-else-stays ()
  "Only the rows this package hid come back when the mode goes."
  (set-window-parameter nil 'tab-line-format 'mine)
  (modern-tabs-line-mode 1)
  (modern-tabs-line-mode -1)
  (should (eq (window-parameter nil 'tab-line-format) 'mine))
  (set-window-parameter nil 'tab-line-format nil))

(ert-deftest modern-tabs-line-test-hiding-can-be-turned-off ()
  "With `modern-tabs-line-auto-hide' nil no window parameter is touched."
  (let ((modern-tabs-line-auto-hide nil))
    (set-window-parameter nil 'tab-line-format nil)
    (modern-tabs-line-update-window)
    (should-not (window-parameter nil 'tab-line-format)))
  ;; And with it on, a window showing one buffer hides the row.
  (let ((modern-tabs-line-auto-hide t))
    (modern-tabs-line-update-window)
    (should (eq (window-parameter nil 'tab-line-format) 'none))
    (set-window-parameter nil 'tab-line-format nil)))

(defvar modern-tabs-test--borrowed-var 'reader
  "A variable for the borrow tests to keep and give back.")

(ert-deftest modern-tabs-test-a-second-enable-borrows-nothing ()
  "The values a mode borrows are the ones it found the first time.
`define-minor-mode' runs its body on every call and a nil argument
means enable, so a mode enabled twice would record the values it set
itself and give those back instead of the reader's."
  (let ((modern-tabs--borrowed nil)
        (modern-tabs-test--borrowed-var 'reader))
    (should (modern-tabs-borrow 'modern-tabs-test-mode
                               'modern-tabs-test--borrowed-var))
    (setq modern-tabs-test--borrowed-var 'mine)
    (should-not (modern-tabs-borrow 'modern-tabs-test-mode
                                   'modern-tabs-test--borrowed-var))
    (should (modern-tabs-give-back 'modern-tabs-test-mode))
    (should (eq modern-tabs-test--borrowed-var 'reader))
    ;; and a mode that borrowed nothing gives nothing back: its
    ;; teardown must not switch off what the package never touched
    (should-not (modern-tabs-give-back 'modern-tabs-test-mode))))

(ert-deftest modern-tabs-line-test-the-mode-survives-its-own-hook ()
  "A reader may turn this mode on from `tab-line-mode-hook'.
The setup once re-enabled `global-tab-line-mode' there, and the pair
recursed until `max-lisp-eval-depth' gave out — a whole configuration
failed to start.  The mode leaves the row alone now."
  (let ((max-lisp-eval-depth 200)
        (hook (lambda () (modern-tabs-line-mode 1))))
    (add-hook 'tab-line-mode-hook hook)
    (unwind-protect
        (progn
          (modern-tabs-line-mode 1)
          (with-temp-buffer (tab-line-mode 1))
          (should modern-tabs-line-mode))
      (remove-hook 'tab-line-mode-hook hook)
      (modern-tabs-line-mode -1))))

(ert-deftest modern-tabs-line-test-the-tabs-are-the-ones-the-row-shows ()
  "`tab-line-tabs-function' says what the row shows, and a reader may set it."
  (let ((tab-line-tabs-function (lambda () '(a b))))
    (should (modern-tabs-line--several-p)))
  (let ((tab-line-tabs-function (lambda () '(a))))
    (should-not (modern-tabs-line--several-p))))

(provide 'modern-tabs-test)
;;; modern-tabs-test.el ends here
