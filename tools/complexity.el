;;; complexity.el --- How much of a function a reader must hold  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Marcel Arpogaus

;; Author: Marcel Arpogaus <znepry.necbtnhf@tznvy.pbz>
;; Assisted-by: Claude:claude-opus-5

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

;; The measure of this repository, which `make complexity' runs:
;;
;;     emacs -Q --batch -l tools/complexity.el \
;;       --eval '(complexity-report command-line-args-left)' FILE...
;;
;; It scores every function by *cognitive complexity*: how much of it a
;; reader has to hold in their head at once.  The rules are those of the
;; SonarSource white paper, which is language-independent, read here as
;; Lisp:
;;
;; - A form that breaks the straight line costs one: `if', `when',
;;   `while', `dolist', `cond', `pcase', a `condition-case' handler, a
;;   `throw'.
;; - A form nested inside another such form costs one more for each
;;   level it is in.  Two nested `dolist' forms cost 1 + 2, not 1 + 1.
;; - A branch that also has an else costs one more, and a `cond' or
;;   `pcase' costs one for each clause after the first.
;; - A run of the same operator costs one however long it is: `(and a b
;;   c)' costs one, `(and a (or b c))' two.
;; - A sequence of plain calls costs nothing, however long.  Neither
;;   does a long `let', a long doc string, or a comment: the reader of
;;   the score reads code, and the reader of the code reads the prose.
;;
;; What the number is for: finding the functions worth splitting, not
;; passing a gate.  Nothing in this repository fails on a score.  There
;; is no equivalent of complexipy or of ruff's rules for Emacs Lisp —
;; `checkdoc', `package-lint', `relint' and the byte-compiler all say
;; nothing about the shape of a function — so this stands in for them.
;;
;; The rules are checked in test/complexity-test.el.

;;; Code:

(require 'seq)
(require 'subr-x)

(defconst complexity-branching
  '((if . if) (if-let . if) (if-let* . if) (when-let . if) (when-let* . if)
    (and-let* . if) (while-let . if)
    (when . plain) (unless . plain)
    (while . loop) (dolist . loop) (dotimes . loop) (cl-loop . loop)
    (cl-dolist . loop) (cl-dotimes . loop) (seq-doseq . loop)
    (pcase-dolist . loop) (dolist-with-progress-reporter . loop)
    (cl-do . loop) (cl-do* . loop)
    (cond . clauses) (pcase . clauses) (pcase-exhaustive . clauses)
    (cl-case . clauses) (cl-ecase . clauses) (cl-typecase . clauses)
    (condition-case . handlers) (condition-case-unless-debug . handlers)
    (ignore-errors . plain)
    (and . run) (or . run)
    (throw . jump) (cl-return . jump) (cl-return-from . jump)
    (lambda . body) (cl-function . body)
    (cl-flet . nested) (cl-flet* . nested) (cl-labels . nested))
  "What each form costs, by the kind of break in the flow it is.
`if' takes one more for an else, `clauses' one for each clause after the
first, `handlers' one for each handler, `run' one for a sequence of the
same operator however long it is, and `jump' one without the nesting.")

(defconst complexity-definers
  '(defun defmacro defsubst cl-defun cl-defmacro cl-defmethod
          cl-defgeneric define-inline)
  "The forms that define a function this measures.")

(defvar complexity--score 0 "The score of the function being walked.")
(defvar complexity--depth 0 "The deepest nesting seen in it.")
(defvar complexity--forms 0 "How many forms it holds.")
(defvar complexity--name nil "The name of the function being walked.")
(defvar complexity--recurses nil "Whether it calls itself.")

(defun complexity--add (n nest)
  "Add N breaks in the flow, each of them NEST levels deep."
  (setq complexity--score (+ complexity--score n (* n nest))))

(defun complexity--walk (form nest &optional operator)
  "Score FORM, which sits NEST levels deep.
OPERATOR is the `and\\=' or `or\\=' it stands directly inside, where it
does: a run of one operator costs one however long the run is."
  (setq complexity--depth (max complexity--depth nest))
  (when (consp form)
    (setq complexity--forms (1+ complexity--forms))
    (let* ((head (car form))
           (kind (and (symbolp head)
                      (cdr (assq head complexity-branching)))))
      (cond
       ((memq head '(quote function declare)) nil)
       ((eq kind 'if)
        (complexity--add 1 nest)
        ;; The else is a second way out of one question, which is
        ;; cheaper to read than a question of its own.
        (when (> (safe-length form) 3) (complexity--add 1 0))
        (complexity--walk (nth 1 form) nest)
        (complexity--walk-all (nthcdr 2 form) (1+ nest)))
       ((eq kind 'plain)
        (complexity--add 1 nest)
        (complexity--walk (nth 1 form) nest)
        (complexity--walk-all (nthcdr 2 form) (1+ nest)))
       ((eq kind 'loop)
        (complexity--add 1 nest)
        (complexity--walk-all (cdr form) (1+ nest)))
       ((eq kind 'clauses)
        (complexity--add 1 nest)
        (let ((clauses (if (eq head 'cond) (cdr form) (nthcdr 2 form))))
          (complexity--add (max 0 (1- (safe-length clauses))) 0)
          (unless (eq head 'cond) (complexity--walk (nth 1 form) nest))
          (complexity--walk-all clauses (1+ nest))))
       ((eq kind 'handlers)
        ;; One for each handler, and one for a form that catches
        ;; nothing: the jump out of the body is the break in the flow.
        (complexity--add (max 1 (safe-length (nthcdr 3 form))) nest)
        (complexity--walk-all (cdr form) (1+ nest)))
       ((eq kind 'run)
        (unless (eq operator head) (complexity--add 1 0))
        (dolist (x (cdr form)) (complexity--walk x nest head)))
       ((eq kind 'jump)
        (complexity--add 1 0)
        (complexity--walk-all (cdr form) nest))
       ((eq kind 'body) (complexity--walk-all (cddr form) (1+ nest)))
       ((eq kind 'nested) (complexity--walk-all (cdr form) (1+ nest)))
       (t
        (when (eq head complexity--name) (setq complexity--recurses t))
        ;; Along the tail, so a dotted or improper form is walked as far
        ;; as it goes rather than signalling.
        (let ((tail form))
          (while (consp tail)
            (complexity--walk (car tail) nest)
            (setq tail (cdr tail)))))))))

(defun complexity--walk-all (forms nest)
  "Score every form of FORMS, each of them NEST levels deep."
  (dolist (form forms) (complexity--walk form nest)))

(defun complexity-of (definition)
  "Return what the function DEFINITION costs a reader, as a plist.
DEFINITION is a `defun\\=' form as `read\\=' answers it.  The keys are
`:score\\=', `:depth\\=', `:forms\\=' and `:recurses\\='."
  (setq complexity--score 0
        complexity--depth 0
        complexity--forms 0
        complexity--name (nth 1 definition)
        complexity--recurses nil)
  (complexity--walk-all (nthcdr 3 definition) 0)
  ;; A function that calls itself asks the reader to hold it twice.
  (when complexity--recurses (complexity--add 1 0))
  (list :score complexity--score :depth complexity--depth
        :forms complexity--forms :recurses complexity--recurses))

(defun complexity-file (file)
  "Return a plist for every function FILE defines.
Beside what `complexity-of\\=' answers: `:name\\=', `:line\\=', `:file\\=', and
the lines of the definition told apart as `:code\\=', `:doc\\=', `:comment\\='
and `:blank\\='.  Comments never reach the score — the reader drops them —
so a long explanation costs nothing and a dense line costs a great
deal."
  (with-temp-buffer
    (insert-file-contents file)
    (emacs-lisp-mode)
    (goto-char (point-min))
    (let (found)
      (while (progn (forward-comment (buffer-size)) (not (eobp)))
        (let* ((beg (point))
               (line (line-number-at-pos beg))
               (form (condition-case nil (read (current-buffer))
                       ;; A file this Emacs cannot read is not a file
                       ;; this can measure; what was read still counts.
                       (error (goto-char (point-max)) nil)))
               (text (buffer-substring-no-properties beg (point))))
          (when (and (consp form) (memq (car form) complexity-definers))
            (let* ((doc (and (stringp (nth 3 form)) (nth 3 form)))
                   (lines (split-string text "\n"))
                   (blank (seq-count (lambda (l)
                                       (string-match-p "\\`[ \t]*\\'" l))
                                     lines))
                   (comment (seq-count (lambda (l)
                                         (string-match-p "\\`[ \t]*;" l))
                                       lines))
                   (docl (if doc
                             (1+ (seq-count (lambda (c) (eq c ?\n)) doc))
                           0)))
              (push (append (list :name (nth 1 form) :file file :line line
                                  :lines (length lines) :doc docl
                                  :comment comment :blank blank
                                  :code (- (length lines) docl comment blank))
                            (complexity-of form))
                    found)))))
      (nreverse found))))

(defun complexity-report (files)
  "Print what every function of FILES costs a reader, the dearest first."
  (let* ((all (sort (mapcan #'complexity-file files)
                    ;; Not the keyword form, which is Emacs 30: this
                    ;; repository declares 29.1 and its tools run there.
                    (lambda (a b) (> (plist-get a :score)
                                     (plist-get b :score)))))
         (scores (mapcar (lambda (r) (plist-get r :score)) all))
         (over (seq-filter (lambda (r) (> (plist-get r :score) 15)) all)))
    (princ (format "%-42s %-26s %4s %4s %6s %5s\n"
                   "FUNCTION" "FILE:LINE" "COST" "DEEP" "FORMS" "CODE"))
    (dolist (r all)
      (princ (format "%-42s %-26s %4d %4d %6d %5d\n"
                     (plist-get r :name)
                     (format "%s:%d"
                             (file-name-nondirectory (plist-get r :file))
                             (plist-get r :line))
                     (plist-get r :score) (plist-get r :depth)
                     (plist-get r :forms) (plist-get r :code))))
    (princ (format "\n%d functions, %d in all, %.1f each, most %d.\n"
                   (length all) (apply #'+ 0 scores)
                   (/ (float (apply #'+ 0 scores)) (max 1 (length all)))
                   (apply #'max 0 scores)))
    ;; Fifteen is where SonarSource puts its own gate.  Nothing here
    ;; fails on it: it is a place to look, not a rule.
    (princ (format "%d over 15%s\n" (length over)
                   (if over
                       (concat ": " (mapconcat
                                     (lambda (r)
                                       (format "%s" (plist-get r :name)))
                                     over ", "))
                     "")))))

(provide 'complexity)
;;; complexity.el ends here
