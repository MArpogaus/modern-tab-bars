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
`modern-tab-line-tab-format\\=', which puts it in front of the name the
row formats: the face of a terminal bar would not survive the
`propertize\\=' that formatting does."
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
  (let ((tab-bar-close-button "X")
        (tab-bar-tab-hints nil)
        ;; A tab is an alist whose car says which kind it is.
        (tab '(current-tab (name . "one"))))
    (let ((tab-bar-close-button-show 'selected))
      (should (string-suffix-p "X" (modern-tab-bar-name-format tab 1))))
    (let ((tab-bar-close-button-show 'non-selected))
      (should-not (string-suffix-p "X" (modern-tab-bar-name-format tab 1))))
    (let ((tab-bar-close-button-show nil))
      (should-not (string-suffix-p "X" (modern-tab-bar-name-format tab 1))))))

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

(ert-deftest modern-tab-bar-test-the-format-drops-the-menu-in-a-terminal ()
  "The menu button leaves a terminal's tab bar row blank, so it goes."
  (skip-unless (not (display-graphic-p)))
  (should-not (memq 'tab-bar-format-menu-bar (modern-tab-bar--format)))
  (should (memq 'tab-bar-format-tabs-groups (modern-tab-bar--format))))

(ert-deftest modern-tab-bar-test-the-new-button-runs-the-command-it-is-given ()
  "`modern-tab-bar-new-command' is what the button of the format runs."
  (let ((modern-tab-bar-new-command #'ignore)
        (tab-bar-new-button "+"))
    (should (equal (modern-tab-bar-format-new-button)
                   '((add-tab menu-item "+" ignore :help "New"))))))

(ert-deftest modern-tab-bar-test-the-mode-gives-the-tab-bar-back ()
  "Turning the mode off gives back what the reader had, not what custom says.
Every variable the mode sets, including the two buttons and the format:
`custom-reevaluate-setting' was the restore before this, and it reads
the custom file — so a value set with `setq' was thrown away and a
plain `defvar' was set to nil."
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
                (current-buffer)))))

(ert-deftest modern-tab-line-test-closing-a-tab-kills-the-buffer ()
  "A buffer no other window shows is killed when its tab closes."
  (let ((buffer (generate-new-buffer "modern-tab-line-test")))
    (should (buffer-live-p buffer))
    (modern-tab-line-close-tab buffer)
    (should-not (buffer-live-p buffer))))

(ert-deftest modern-tab-line-test-the-mode-gives-the-tab-line-back ()
  "Turning the mode off gives back every variable it set, the button too.
`tab-line-close-button' is a plain `defvar', so the restore that read
the custom file set it to nil and left the stock tab line with no close
button at all."
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
      (should (memq #'modern-tab-line-update-window buffer-list-update-hook))
      (should global-tab-line-mode)
      (modern-tab-line-mode -1)
      (should (equal (list tab-line-separator tab-line-tab-name-function
                           tab-line-close-tab-function
                           tab-line-new-button-show
                           tab-line-close-button-show tab-line-close-button)
                     was))
      (should-not (memq #'modern-tab-line-update-window
                        buffer-list-update-hook))
      (should-not global-tab-line-mode))))

(ert-deftest modern-tab-line-test-a-row-the-reader-had-stays ()
  "A `global-tab-line-mode' that was on before the mode stays on after it."
  (global-tab-line-mode 1)
  (modern-tab-line-mode 1)
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
    (modern-tab-line-update-window)
    (should-not (window-parameter nil 'tab-line-format)))
  ;; And with it on, a window showing one buffer hides the row.
  (let ((modern-tab-line-auto-hide t))
    (modern-tab-line-update-window)
    (should (eq (window-parameter nil 'tab-line-format) 'none))
    (set-window-parameter nil 'tab-line-format nil)))

(defvar modern-tab-test--borrowed-var 'reader
  "A variable for the borrow tests to keep and give back.")

(ert-deftest modern-tab-test-a-second-enable-borrows-nothing ()
  "The values a mode borrows are the ones it found the first time.
`define-minor-mode' runs its body on every call and a nil argument
means enable, so a mode enabled twice would record the values it set
itself and give those back instead of the reader's."
  (let ((modern-tab--borrowed nil)
        (modern-tab-test--borrowed-var 'reader))
    (should (modern-tab-borrow 'modern-tab-test-mode
                               'modern-tab-test--borrowed-var))
    (setq modern-tab-test--borrowed-var 'mine)
    (should-not (modern-tab-borrow 'modern-tab-test-mode
                                   'modern-tab-test--borrowed-var))
    (should (modern-tab-give-back 'modern-tab-test-mode))
    (should (eq modern-tab-test--borrowed-var 'reader))
    ;; and a mode that borrowed nothing gives nothing back: its
    ;; teardown must not switch off what the package never touched
    (should-not (modern-tab-give-back 'modern-tab-test-mode))))

(ert-deftest modern-tab-line-test-the-tabs-are-the-ones-the-row-shows ()
  "`tab-line-tabs-function' says what the row shows, and a reader may set it."
  (let ((tab-line-tabs-function (lambda () '(a b))))
    (should (modern-tab-line--several-p)))
  (let ((tab-line-tabs-function (lambda () '(a))))
    (should-not (modern-tab-line--several-p))))

(provide 'modern-tab-test)
;;; modern-tab-test.el ends here
