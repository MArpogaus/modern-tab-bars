# Development tasks.  Run `make' to check everything, as the CI does.
#
#   make compile   byte-compile, warnings are errors
#   make checkdoc  documentation style
#   make lint      package-lint, the MELPA rules
#   make test      ERT test suite
#   make relint    the regular expressions
#   make clean     remove build output and the tool sandbox
#
# The checks install their tools and this package's dependencies into
# $(SANDBOX), so a fresh checkout needs nothing but Emacs and make.

EMACS   ?= emacs
SANDBOX ?= .sandbox
DEPS    ?= package-lint relint

SRC  := $(filter-out %-autoloads.el %-pkg.el,$(wildcard *.el))
TEST := $(wildcard test/*.el)

# Elisp programs live in variables: make joins their continuation lines,
# while a backslash inside a quoted recipe line would reach Emacs as is.
init = (progn (setq package-user-dir (expand-file-name "$(SANDBOX)")) \
              (require (quote package)) \
              (add-to-list (quote package-archives) \
                           (cons "melpa" "https://melpa.org/packages/") t) \
              (package-initialize))
bootstrap = (progn (package-refresh-contents) \
                   (dolist (p (quote ($(DEPS)))) \
                     (unless (package-installed-p p) (package-install p))))
checkdoc = (progn (require (quote checkdoc)) \
                  (setq checkdoc-verb-check-experimental-flag nil) \
                  (dolist (f command-line-args-left) (checkdoc-file f)))

BATCH = $(EMACS) -Q --batch -L . -L test -L tools --eval '$(init)'

.PHONY: all compile checkdoc lint relint test clean

all: compile checkdoc lint relint test

$(SANDBOX):
	@$(EMACS) -Q --batch --eval '$(init)' --eval '$(bootstrap)'

compile: $(SANDBOX)
	@$(BATCH) --eval '(setq byte-compile-error-on-warn t)' \
	  -f batch-byte-compile $(SRC) $(TEST)
	@rm -f ./*.elc test/*.elc

# checkdoc reports on stderr and always exits zero, so treat any output
# as a failure.
checkdoc:
	@out=$$($(BATCH) --eval '$(checkdoc)' $(SRC) 2>&1); \
	  if [ -n "$$out" ]; then printf '%s\n' "$$out"; exit 1; fi

# One package, three files: package-lint reads the headers of the main
# file for all of them, as MELPA does.
lint: $(SANDBOX)
	@$(BATCH) --eval '(setq package-lint-main-file "modern-tab.el")' \
	  -f package-lint-batch-and-exit $(SRC)

relint: $(SANDBOX)
	@$(BATCH) -l relint -f relint-batch $(SRC) $(TEST)
test: $(SANDBOX)
	@$(BATCH) $(addprefix -l ,$(TEST)) -f ert-run-tests-batch-and-exit

clean:
	@rm -rf $(SANDBOX) ./*.elc test/*.elc
