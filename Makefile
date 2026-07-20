EMACS ?= emacs
BATCH = $(EMACS) -Q --batch
LOAD_PATH = -L . -L test
LOAD_SETUP = --eval "(setq load-prefer-newer t)"
GRAMMAR_DIR ?= $(CURDIR)/.tree-sitter
GRAMMAR_SETUP = --eval "(add-to-list 'treesit-extra-load-path \"$(GRAMMAR_DIR)\")"
GRAMMAR_URL = https://github.com/ngalaiko/tree-sitter-go-template
GRAMMAR_REV = aa71f63de226c5592dfbfc1f29949522d7c95fac
SOURCES = go-template-ts-mode.el go-template-ts-mode-treesit-fold.el
TEST_SOURCES = test/go-template-ts-mode-test.el

.PHONY: all install-grammar compile test test-optional-fold clean

all: compile test

install-grammar:
	mkdir -p $(GRAMMAR_DIR)
	$(BATCH) \
		--eval "(require 'treesit)" \
		$(GRAMMAR_SETUP) \
		--eval "(add-to-list 'treesit-language-source-alist '(gotmpl \"$(GRAMMAR_URL)\" \"$(GRAMMAR_REV)\"))" \
		--eval "(unless (treesit-language-available-p 'gotmpl) (treesit-install-language-grammar 'gotmpl \"$(GRAMMAR_DIR)\"))"

compile:
	$(BATCH) $(LOAD_PATH) $(LOAD_SETUP) \
		--eval "(setq byte-compile-error-on-warn t)" \
		-f batch-byte-compile $(SOURCES)

test: install-grammar test-optional-fold
	$(BATCH) $(LOAD_PATH) $(LOAD_SETUP) $(GRAMMAR_SETUP) \
		-l go-template-ts-mode-test \
		-f ert-run-tests-batch-and-exit

test-optional-fold:
	@set -e; tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' 0; \
		mkdir "$$tmp/test"; \
		cp $(SOURCES) "$$tmp"; \
		cp $(TEST_SOURCES) "$$tmp/test"; \
		$(BATCH) -L "$$tmp" -L "$$tmp/test" \
			--eval "(setq byte-compile-error-on-warn t)" \
			-f batch-byte-compile "$$tmp"/*.el "$$tmp"/test/*.el; \
		$(BATCH) -L "$$tmp" \
			--eval "(defvar treesit-fold-range-alist nil)" \
			--eval "(provide 'treesit-fold)" \
			-l go-template-ts-mode \
			--eval "(unless (alist-get 'go-template-ts-mode treesit-fold-range-alist) (error \"Go Template fold ranges were not registered\"))"

clean:
	find . -name '*.elc' -delete
